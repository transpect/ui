(: TODO:CLEAN-UP, INTEGRATE, JS :)

module namespace data = 'http://le-tex.de/data';

import module namespace hf = 'http://le-tex.de/helper-functions' at '/opt/basex/webapp/transpectui/helper-functions.xqm';
import module namespace ns = 'http://le-tex.de/namespaces' at '/opt/basex/webapp/transpectui/namespaces.xqm';

declare variable $data:use-search-cache := false();
declare variable $data:use-object-cache := false();
declare variable $data:search-log       := true();
declare variable $data:message-log      := true();
declare variable $data:error-log        := true();
declare variable $data:store-log        := false();
declare variable $data:store-log-ws     := true();
declare variable $data:store-log-oc     := false();
declare variable $data:store-log-sc     := false();
declare variable $data:store-log-hb     := false();
declare variable $data:emit-log         := false();
declare variable $data:send-log         := false();
declare variable $data:calltemplate     := 
  <call type="run" method="get">
    <ids worker-id="gandalf" converter-id="brepols" runid="37de5"></ids>
  </call>;


declare
  %ws:connect('/data') 
function data:connect() {
  let $pageid := random:uuid(),
      $log := hf:log('ws: ' || ws:id() || ' pg: ' || $pageid || 'username: ' || session:get('username'), 'CONNECT', $data:store-log-ws),
      $put-ws := store:put('ws:' || ws:id(),map {'pageid': $pageid}),
      $put-pg := store:put('pg:' || $pageid,map {'username': session:get('username')}),
      $send-init := 
        data:send-data(
          ws:id(),
          'init',
          element return {
            attribute action {'init'},
            attribute id {'ws-data'},
            element connection {
              attribute ws-id {ws:id()},
              attribute page-id {$pageid}
            }
          }
        )
  return ()
};

declare
  %ws:error('/data', '{$error}') 
function data:error($error) {
  hf:log('Error for ' || ws:id() || ' occured because of ' || $error,'WS-ERROR',$data:error-log)
};

declare
  %ws:close('/data') 
function data:close() {
  hf:log('ws: ' || ws:id(), 'DICONNECT', $data:store-log-ws),
  let $pg := store:get('ws:' || ws:id())?pageid
  return store:remove('pg:' || $pg),
  store:remove('ws:' || ws:id()) (:CLEANUP:)
  
};

declare
  %ws:message('/data', '{$message}') 
function data:message-pre($message as xs:string) {
  let $id := hf:id('websocket-call'),
      $ws-id := ws:id(),
      $is-heartbeat := matches($message,'^HEARTBEAT'),
      $run :=
        if ($is-heartbeat)
        then
          if (tokenize($message,':')[2])
          then
            hf:eval(
              $ns:user,
              "u:update-timestamp($username)",
              map {'username':tokenize($message,':')[2]},
              map {'id': $id,'cache':true()}
            )
          else ()
        else
          hf:eval(
            $ns:data,
            "data:message($ws-id, $message)",
            map {'ws-id':$ws-id,'message':$message},
            map {'id': $id,'cache':true()}
          )
  return ()
};

declare function data:message($ws-id as xs:string, $message as xs:string) {
  let $element := parse-xml($message),
      $method := $element/call/xs:string(@method),
      $call := $element/call,
      $log := hf:log('ws: ' || $ws-id || ' message: ' || $message || ' method: ' || $method,'MESSAGE',$data:message-log),
      $return :=
        switch ($method)
        case "get" return data:get-data($ws-id, $call)
        case "search" return data:search-data($ws-id, $call)
        default return ()
  return ()
};

declare function data:get-data($ws-id as xs:string, $call as element(call)) {
  switch (xs:string($call/@type))
  case "run"
  return 
    let $worker-id := $call/ids/@worker-id,
        $converter-id := $call/ids/@converter-id,
        $runid := $call/ids/@runid,
        $object-id := xs:string($call/@type)|| ':' || string-join(($worker-id, $converter-id, $runid),'|'),
        $local := not(exists($worker-id)),
        $call :=
          if ($local)
          then 
            "let $converter := tr:get-local-converter($converter-id),
                 $run := tr:get-run($runid, $converter)
             return data:send-data($ws-id, $object-id,$run)"
          else
            "let $worker := tr:get-worker($worker-id),
                 $converter := tr:get-worker-converter($worker, $converter-id),
                 $run := tr:get-run($runid, $converter, $worker)
             return data:send-data($ws-id, $object-id, $run)"
    return hf:eval(($ns:data,$ns:tr),$call,
              map {'ws-id': $ws-id,'object-id': $object-id,'worker-id': $worker-id,'converter-id': $converter-id,'runid': $runid},
              map {'id': hf:id('get_run' || $object-id), 'cache': true()})
  default return hf:log('no matching type: ' || $call/@type)
};

declare function data:search-data($ws-id as xs:string, $call as element(call)) {
  switch (xs:string($call/@type))
  case "run"
  return 
    let $worker-id := $call/ids/@worker-id,
        $converter-id := $call/ids/@converter-id,
        $username := $call/ids/@username,
        $local := not(exists($worker-id)),
        $object-id := xs:string($call/@type)|| ':' || string-join(($worker-id, $converter-id, $username),'|'),
        $call :=
          if ($local)
          then 
            "let $converter := tr:get-local-converter($converter-id),
                 $runs := tr:get-runs($converter, $username)
             return data:send-data($ws-id, $object-id, $runs)"
          else
            "let $worker := tr:get-worker($worker-id),
                 $converter := tr:get-worker-converter($worker, $converter-id),
                 $runs := tr:get-runs($converter, $username)
             return data:send-data($ws-id, $object-id, $runs)"
    return hf:eval(($ns:data,$ns:tr),$call,
              map {'ws-id': $ws-id,'object-id': $object-id,'worker-id': $worker-id,'converter-id': $converter-id, 'username':$username},
              map {'id': hf:id('search_runs' || $object-id), 'cache': true()})
  default return hf:log('no matching type: ' || $call/@type)
};

declare function data:send-data($ws-id, $object-id, $data) {
  let $log := hf:log(serialize($data),'SEND',$data:send-log)
  return (
      ws:send(
        <result code="200" object-id="{$object-id}" timestamp="{convert:dateTime-to-integer(fn:current-dateTime())}">
          <display-text></display-text>
          <data id="ws-data">{$data}</data>
        </result>,
        $ws-id
      ))
};

declare function data:get-online-users() as xs:string* {
  for $ws-id in ws:ids()
  let $pg := store:get('ws:' || $ws-id)?pageid,
      $username := store:get('pg:' || $pg)?username
  return $username
};