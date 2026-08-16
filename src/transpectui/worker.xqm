module namespace worker = 'http://le-tex.de/worker';

import module namespace hf = 'http://le-tex.de/helper-functions' at '/opt/basex/webapp/transpectui/helper-functions.xqm';
import module namespace config = 'http://le-tex.de/config' at '/opt/basex/webapp/transpectui/config.xqm';

declare variable $worker:worker := $config:file/configurations/configuration/controller/worker;
declare variable $worker:is-controller := $config:file/configurations/configuration/controller/activated eq "true";

(:
 : Orchestrate Workers Available in $worker:worker
 :)

declare function worker:converter($worker as element(worker)? := (), $converter-id as xs:string? := ()) as element(converter)*{
  if ($worker)
  then worker:get-converter($worker)[@id eq $converter-id or not(exists($converter-id))]
  else
    for $worker in $worker:worker
    return worker:get-converter($worker)[@id eq $converter-id or not(exists($converter-id))]
};

declare function worker:get-runs($element as (element(converter)|element(worker))) as element(run)*{
  if ($element instance of element(converter))
  then
    let $worker := $worker:worker[@id eq $element/@worker]   
    return worker:get($worker, string-join(('','api','en','converter', $element/@id, 'runs'),'/'))[2]/*/run
  else 
    let $converter-ids := worker:get-converter($element)/@id
    return for $id in $converter-ids return worker:get($element, string-join(('','api','en','converter', $id, 'runs'),'/'))[2]/*/run
};

declare function worker:get-run($element as (element(converter)|element(worker)), $runid) as element(run)? {
  if ($element instance of element(converter))
  then
    let $worker := $worker:worker[@id eq $element/@worker]   
    return worker:get($worker, string-join(('','api','en','converter', $element/@id, 'runs', $runid),'/'))[2]/run/run
  else 
    let $converter-ids := worker:get-converter($element)/@id
    return for $id in $converter-ids return worker:get($element, string-join(('','api','en','converter', $id, 'runs'),'/'))[2]/run
};

declare function worker:stop-run($converter as element(converter), $runid, $username) {
  let $worker := worker:get-by-id($converter/@worker)
  return worker:get($worker, string-join(('','api','en','converter', $converter/@id, 'runs', $runid,'cancel'),'/'),map {'username': $username})[2]
};

declare function worker:get-file-logs($converter as element(converter), $run) as element(line)* {
  let $worker := worker:get-by-id($converter/@worker)
  return worker:get($worker, string-join(('','api','en','converter', $converter/@id, 'runs', $run/runid,'logs'),'/'))[2]//line
};

declare %private function worker:get-converter($worker as element(worker)) {
  worker:get($worker,'/api/en/converter')[2]/* update {insert node attribute worker {$worker/@id} into .}
};

declare function worker:get($worker as element(worker), $url, $header := map {}) {
  let $result := worker:request($worker/base-url || $url, for $k in map:keys($header) return <http:header name='{$k}' value='{$header?$k}'/>)
  return $result
};

declare function worker:convert($worker as element(worker), $converter-id as xs:string, $file as map(xs:string, xs:base64Binary), $username as xs:string? := 'transpectui') as element(run)?{
  worker:post($worker,'/api/en/converter/' || $converter-id, $file, $username)[2]/run
};

declare function worker:post($worker as element(worker), $url as xs:string, $file as map(xs:string, xs:base64Binary), $username as xs:string) {
  let $header :=( 
        <http:header name='username' value='{$username}'/>,
        <http:multipart media-type='multipart/form-data'>
          <http:header name='content-disposition'
            value='form-data; name="file"; filename="{ map:keys($file)[1] }"'/>
          <http:body media-type='application/octet-stream'/>
        </http:multipart>),
      $result := worker:request($worker/base-url || $url, $header, map:items($file)[1], 'POST'),
      $store := store:put('post',$result)
return $result
};

declare function worker:get-by-id($worker-id as xs:string){
  $worker:worker[@id eq $worker-id]
};

(: 
 : most basic request wrapper
 :)
declare %private function worker:request($url, $header := (), $body as item()* := (), $method as xs:string := 'get') {
  http:send-request( 
    element http:request {
      attribute method {$method},
      $header
    },
    $url,
    $body
  )
};