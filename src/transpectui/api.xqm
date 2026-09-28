module namespace api = 'http://le-tex.de/api';

import module namespace conv = 'http://le-tex.de/converter' at 'converter.xqm';
import module namespace config = 'http://le-tex.de/config' at 'config.xqm';
import module namespace hf = 'http://le-tex.de/helper-functions' at 'helper-functions.xqm';
import module namespace i18n = 'http://le-tex.de/i18n' at 'i18n.xqm';
import module namespace u = 'http://le-tex.de/user' at 'user.xqm';
import module namespace tr = 'http://le-tex.de/transpect' at '/opt/basex/webapp/transpectui/transpect.xqm';
import module namespace ns = 'http://le-tex.de/namespaces' at '/opt/basex/webapp/transpectui/namespaces.xqm';

declare variable $api:config := $config:file/configurations/configuration/api;
declare variable $api:is-worker := not($config:file/configurations/configuration/controller/@activated eq "true"); (: ALL Calls are allowed:)

declare
  %rest:GET
  %rest:path("/api")
  %output:method("xml")
function api:overview(){
  api:overview('en')
};

declare
  %rest:GET
  %rest:path("/api/{$lang}")
  %output:method("xml")
function api:overview($lang as xs:string){
  string-join(
    (
      'List of supported api-endpoints:',
      for $fn in inspect:module($ns:api ! replace(.,".* at '|';",''))/function[annotation[@name eq 'rest:path']]
      let $method := $fn/annotation[matches(@name,'rest:(GET|POST|DELETE|PUT|PATCH|HEAD|OPTIONS|TRACE)')]/replace(@name,'rest:',''),
  	      $path := $fn/annotation[@name eq 'rest:path']/literal/text()
      return ($method || ': ' || $path)
    ),'
  ')
};

declare
  %rest:GET
  %rest:path("/api/{$lang}/status")
  %output:method("xml")
function api:get-status($lang as xs:string){
  let $headers as map(xs:string, xs:string*):= request:header-map(),
      $authed := api:auth($headers),
      $username := $authed/username
  return 
    if (xs:boolean($authed/@allowed))
    then api:status()
    else api:error(i18n:val($authed/messages/text(),$lang))
};

declare
  %rest:GET
  %rest:path("/api/{$lang}/converter")
  %output:method("xml")
function api:get-converters($lang as xs:string){
  let $headers as map(xs:string, xs:string*):= request:header-map(),
      $authed := api:auth($headers),
      $username := $authed/username,
      $converter as element(converter)* := api:converter($username, $lang)
  return 
    if (xs:boolean($authed/@allowed))
    then $converter
    else api:error(i18n:val($authed/messages/text(),$lang))
};

declare
  %rest:GET
  %rest:path("/api/{$lang}/converter/{$converter-id}")
  %output:method("xml")
function api:get-converter($converter-id as xs:string, $lang as xs:string){
  let $headers as map(xs:string, xs:string*):= request:header-map(),
      $authed as element(auth):= api:auth($headers),
      $username := $authed/username,
      $converter as element(converter)? := api:converter($converter-id, $username, $lang)
  return 
    if (xs:boolean($authed/@allowed))
    then $converter
    else api:error(i18n:val($authed/messages/text(),$lang))
};

declare
  %rest:POST
  %rest:path("/api/{$lang}/converter/{$converter-id}")
  %rest:form-param('file', '{$file}')
  %output:method("xml")
function api:convert($file as map(xs:string, xs:base64Binary), $converter-id as xs:string, $lang as xs:string){
  let $headers as map(xs:string, xs:string*):= request:header-map(),
      $authed as element(auth):= api:auth($headers),
      $username := $authed/username,
      $text-params := map:remove(request:parameter-map(),('file','file')),
      $right := $converter-id || ':convert',
      $is-allowed := (api:can-do($right, $username) and xs:boolean($authed/@allowed)),
      $converter as element(converter)? := api:converter($converter-id, $username, $lang),
      $run as (element(error)|element(run)) :=
        if ($is-allowed)
        then tr:start-run($file, $text-params, $converter, $username)
        else element error {i18n:val('not-allowed-message',$lang)}
  return $run
};

declare
  %rest:GET
  %rest:path("/api/{$lang}/converter/{$converter-id}/runs")
  %output:method("xml")
function api:get-converter-runs($converter-id as xs:string, $lang as xs:string){
  let $headers as map(xs:string, xs:string*):= request:header-map(),
      $authed as element(auth):= api:auth($headers),
      $converter := conv:get($converter-id),
      $username := $authed/username,
      $runs as element(runs) := if ($username ne 'not-found') then tr:get-runs($converter,$username) else element runs {tr:get-runs($converter)},
      $user := u:users($username)
  return 
    if (xs:boolean($authed/@allowed))
    then $runs
    else api:error(i18n:val($authed/messages/text(),$lang))
};

declare
  %rest:GET
  %rest:path("/api/{$lang}/converter/{$converter-id}/runs/{$runid}")
  %output:method("xml")
function api:get-converter-run($converter-id as xs:string, $runid as xs:string ,$lang as xs:string){
  let $headers as map(xs:string, xs:string*):= request:header-map(),
      $authed as element(auth):= api:auth($headers),
      $username := $authed/username,
      $converter as element(converter)? := tr:get-local-converter($converter-id),
      $run as element(run) := tr:get-run($runid),
      $out-path := $run/params/line[matches(.,'OUT_DIR')] ! tokenize(.,'=')[2],
      $result-files := tr:get-result-files($run, $converter)
  return 
    if (xs:boolean($authed/@allowed))
    then $run update {insert node $result-files into .}
    else api:error(i18n:val($authed/messages/text(),$lang))
};

declare
  %rest:DELETE
  %rest:path("/api/{$lang}/converter/{$converter-id}/runs/{$runid}")
  %output:method("xml")
function api:delete-converter-run($converter-id as xs:string, $runid as xs:string ,$lang as xs:string){
  let $headers as map(xs:string, xs:string*):= request:header-map(),
      $authed as element(auth):= api:auth($headers),
      $username := $authed/username,
      $converter as element(converter)? := tr:get-local-converter($converter-id),
      $run as element(run) := tr:get-run($runid)
  return 
    if (xs:boolean($authed/@allowed))
    then tr:delete-run($run, $converter)
    else api:error(i18n:val($authed/messages/text(),$lang))
};

declare
  %rest:GET
  %rest:path("/api/{$lang}/converter/{$converter-id}/runs/{$runid}/logs")
  %output:method("xml")
function api:get-converter-run-file-logs($converter-id as xs:string, $runid as xs:string ,$lang as xs:string){
  let $headers as map(xs:string, xs:string*):= request:header-map(),
      $authed as element(auth):= api:auth($headers),
      $username := $authed/username,
      $converter as element(converter)? := tr:get-local-converter($converter-id),
      $run as element(run) := tr:get-run($runid),
      $out-path := $run/params/line[matches(.,'OUT_DIR')] ! tokenize(.,'=')[2],
      $file-logs := tr:get-file-logs($run, $converter)
  return 
    if (xs:boolean($authed/@allowed))
    then element file-log {$file-logs}
    else api:error(i18n:val($authed/messages/text(),$lang))
};

declare
  %rest:GET
  %rest:path("/api/{$lang}/converter/{$converter-id}/runs/{$runid}/job-messages")
  %output:method("xml")
function api:get-converter-run-job-messages($converter-id as xs:string, $runid as xs:string ,$lang as xs:string){
  let $headers as map(xs:string, xs:string*):= request:header-map(),
      $authed as element(auth):= api:auth($headers),
      $username := $authed/username,
      $converter as element(converter)? := tr:get-local-converter($converter-id),
      $run as element(run) := tr:get-run($runid),
      $out-path := $run/params/line[matches(.,'OUT_DIR')] ! tokenize(.,'=')[2],
      $file-logs := for $line in tr:get-job-messages($run, $converter) return element line {$line}
  return 
    if (xs:boolean($authed/@allowed))
    then element log-messages {$file-logs}
    else api:error(i18n:val($authed/messages/text(),$lang))
};

declare
  %rest:GET
  %rest:path("/api/{$lang}/converter/{$converter-id}/runs/{$runid}/job-errors")
  %output:method("xml")
function api:get-converter-run-job-errors($converter-id as xs:string, $runid as xs:string ,$lang as xs:string){
  let $headers as map(xs:string, xs:string*):= request:header-map(),
      $authed as element(auth):= api:auth($headers),
      $username := $authed/username,
      $converter as element(converter)? := tr:get-local-converter($converter-id),
      $run as element(run) := tr:get-run($runid),
      $out-path := $run/params/line[matches(.,'OUT_DIR')] ! tokenize(.,'=')[2],
      $file-logs := for $line in tr:get-job-errors($run, $converter) return element line {$line}
  return 
    if (xs:boolean($authed/@allowed))
    then element log-errors {$file-logs}
    else api:error(i18n:val($authed/messages/text(),$lang))
};

declare
  %rest:GET
  %rest:path("/api/{$lang}/converter/{$converter-id}/runs/{$runid}/files")
  %output:method("xml")
function api:get-converter-run-file-results($converter-id as xs:string, $runid as xs:string ,$lang as xs:string){
  let $headers as map(xs:string, xs:string*):= request:header-map(),
      $authed as element(auth):= api:auth($headers),
      $username := $authed/username,
      $converter as element(converter)? := tr:get-local-converter($converter-id),
      $run as element(run) := tr:get-run($runid),
      $out-path := $run/params/line[matches(.,'OUT_DIR')] ! tokenize(.,'=')[2],
      $files := tr:get-result-files($run, $converter)
  return 
    if (xs:boolean($authed/@allowed))
    then element result-files {$files}
    else api:error(i18n:val($authed/messages/text(),$lang))
};

declare
  %rest:GET
  %rest:path("/api/{$lang}/converter/{$converter-id}/runs/{$runid}/cancel")
  %output:method("xml")
function api:get-converter-stop-run($converter-id as xs:string, $runid as xs:string ,$lang as xs:string){
  let $headers as map(xs:string, xs:string*):= request:header-map(),
      $authed as element(auth):= api:auth($headers),
      $username := $authed/username,
      $converter as element(converter)? := tr:get-local-converter($converter-id),
      $run as element(run)? := tr:get-run($runid, $converter),
      $stop := tr:stop-run($run, $username)
  return 
    if (xs:boolean($authed/@allowed))
    then element result{$stop}
    else api:error(i18n:val($authed/messages/text(),$lang))
};

declare
  %rest:GET
  %rest:path("/api/{$lang}/converter/{$converter-id}/runs/{$runid}/download/{$filename}")
function api:get-converter-runs-download($converter-id as xs:string, $runid as xs:string ,$lang as xs:string, $filename as xs:string){

  let $run as element(run) := tr:get-run($runid),
      $out-path := $run/params/line[matches(.,'OUT_DIR')] ! tokenize(.,'=')[2],
      $filepath := $out-path || $filename,
      $filesize := file:size($filepath),
      $extention := ($filename => tokenize('[\./]'))[last()],
      $format := $filename ! tokenize('.')[last()],
      $show-direct as xs:boolean := $extention = ('xhtml','html'),
      $result-files :=
        map:merge(
          for $file in file:list($out-path)
          where not(matches($file,'/$')) and not(matches($file, '\.pid$|\.stdout$'))
          return {normalize-space($file): $out-path || normalize-space($file)})
  return 
    if ($filename = map:keys($result-files))
    then file:read-binary($filepath)
    else element error {'File not found!'}
};

declare
  %rest:GET
  %rest:path("/api/{$lang}/worker")
  %output:method("xml")
function api:get-worker($lang as xs:string){
  let $headers as map(xs:string, xs:string*):= request:header-map(),
      $authed := api:auth($headers),
      $username := $authed/username,
      $worker as element(worker)* := tr:get-worker()
  return 
    if (xs:boolean($authed/@allowed))
    then element workers {$worker}
    else api:error(i18n:val($authed/messages/text(),$lang))
};

declare
  %rest:GET
  %rest:path("/api/{$lang}/worker/{$worker-id}/converter")
  %output:method("xml")
function api:get-converters($lang as xs:string, $worker-id as xs:string){
  let $headers as map(xs:string, xs:string*):= request:header-map(),
      $authed := api:auth($headers),
      $username := $authed/username,
      $worker as element(worker)? := tr:get-worker($worker-id),
      $converters as element(converter)* := tr:get-worker-converter($worker)
  return 
    if (xs:boolean($authed/@allowed))
    then element converters {$converters}
    else api:error(i18n:val($authed/messages/text(),$lang))
};

declare
  %rest:GET
  %rest:path("/api/{$lang}/worker/{$worker-id}/converter/{$converter-id}")
  %output:method("xml")
function api:get-converter($worker-id as xs:string, $converter-id as xs:string, $lang as xs:string){
  let $headers as map(xs:string, xs:string*):= request:header-map(),
      $authed := api:auth($headers),
      $username := $authed/username,
      $right := $worker-id || '-' || $converter-id || ':convert',
      
      $worker as element(worker)? := tr:get-worker($worker-id),
      $converter as element(converter)? := tr:get-worker-converter($worker,$converter-id),
      
      $allowed as xs:boolean := api:can-do($right, $username) and xs:boolean($authed/@allowed)
  return 
    if ($allowed)
    then $converter
    else api:error(i18n:val($authed/messages/text(),$lang))
};

declare
  %rest:POST
  %rest:path("/api/{$lang}/worker/{$worker-id}/converter/{$converter-id}")
  %rest:form-param('file', '{$file}')
  %output:method("xml")
function api:convert($worker-id as xs:string, $file as map(xs:string, xs:base64Binary), $converter-id as xs:string, $lang as xs:string){
  let $headers as map(xs:string, xs:string*):= request:header-map(),
      $authed := api:auth($headers),
      $username := $authed/username,
      $worker as element(worker)? := tr:get-worker($worker-id),
      $converter as element(converter)? := tr:get-worker-converter($worker,$converter-id),
      
      $text-params := map:remove(request:parameter-map(),('file','file')),
      
      $right := $worker-id || '-' || $converter-id || ':convert',
      $is-allowed := (api:can-do($right, $username) and xs:boolean($authed/@allowed)),
      $run as (element(error)|element(run)) :=
        if ($is-allowed)
        then tr:start-run($file, $text-params, $converter, $username, $worker)
        else element error {i18n:val('not-allowed-message',$lang)}
  return $run
};

declare
  %rest:GET
  %rest:path("/api/{$lang}/worker/{$worker-id}/converter/{$converter-id}/runs")
  %output:method("xml")
function api:get-converter-runs($worker-id as xs:string, $converter-id as xs:string, $lang as xs:string){
  let $headers as map(xs:string, xs:string*):= request:header-map(),
      $authed := api:auth($headers),
      $username := $authed/username,
      $worker as element(worker)? := tr:get-worker($worker-id),
      $converter as element(converter)? := tr:get-worker-converter($worker,$converter-id),
      $runs as element(runs) := tr:get-runs($converter, $username)
  return 
    if (xs:boolean($authed/@allowed))
    then $runs
    else api:error(i18n:val($authed/messages/text(),$lang))
};

declare
  %rest:GET
  %rest:path("/api/{$lang}/worker/{$worker-id}/converter/{$converter-id}/runs/{$runid}")
  %output:method("xml")
function api:get-converter-run($worker-id as xs:string, $converter-id as xs:string, $runid as xs:string ,$lang as xs:string){
  let $headers as map(xs:string, xs:string*):= request:header-map(),
      $authed := api:auth($headers),
      $username := $authed/username,
      $worker as element(worker)? := tr:get-worker($worker-id),
      $converter as element(converter)? := tr:get-worker-converter($worker,$converter-id),
      $run as element(run)? := tr:get-run($runid, $converter, $worker),
      $result-files as element(file)* := tr:get-result-files($run, $converter, $worker),
      $job-messages := tr:get-job-messages($run, $converter, $worker)
  return 
    if (xs:boolean($authed/@allowed))
    then $run update {insert node $result-files into ., insert node element call-result {$job-messages} into .}
    else api:error(i18n:val($authed/messages/text(),$lang))
};

declare
  %rest:DELETE
  %rest:path("/api/{$lang}/worker/{$worker-id}/converter/{$converter-id}/runs/{$runid}")
  %output:method("xml")
function api:del-converter-run($worker-id as xs:string, $converter-id as xs:string, $runid as xs:string ,$lang as xs:string){
  let $headers as map(xs:string, xs:string*):= request:header-map(),
      $authed := api:auth($headers),
      $username := $authed/username,
      $worker as element(worker)? := tr:get-worker($worker-id),
      $converter as element(converter)? := tr:get-worker-converter($worker,$converter-id),
      $run as element(run)? := tr:get-run($runid, $converter, $worker)
  return 
    if (xs:boolean($authed/@allowed))
    then tr:delete-run($run, $converter, $worker)
    else api:error(i18n:val($authed/messages/text(),$lang))
};

declare
  %rest:GET
  %rest:path("/api/{$lang}/worker/{$worker-id}/converter/{$converter-id}/runs/{$runid}/logs")
  %output:method("xml")
function api:get-converter-run-file-logs($worker-id as xs:string, $converter-id as xs:string, $runid as xs:string ,$lang as xs:string){
  let $headers as map(xs:string, xs:string*):= request:header-map(),
      $authed as element(auth):= api:auth($headers),
      $username := $authed/username,
      $worker as element(worker)? := tr:get-worker($worker-id),
      $converter as element(converter)? := tr:get-worker-converter($worker, $converter-id),
      $run as element(run)? := tr:get-run($runid),
      $file-logs := tr:get-file-logs($run, $converter, $worker)
  return 
    if (xs:boolean($authed/@allowed))
    then element file-log {$file-logs}
    else api:error(i18n:val($authed/messages/text(),$lang))
};

declare
  %rest:GET
  %rest:path("/api/{$lang}/worker/{$worker-id}/converter/{$converter-id}/runs/{$runid}/job-messages")
  %output:method("xml")
function api:get-converter-run-job-messages($worker-id as xs:string, $converter-id as xs:string, $runid as xs:string ,$lang as xs:string){
  let $headers as map(xs:string, xs:string*):= request:header-map(),
      $authed as element(auth):= api:auth($headers),
      $username := $authed/username,
      $worker as element(worker)? := tr:get-worker($worker-id),
      $converter as element(converter)? := tr:get-worker-converter($worker, $converter-id),
      $run as element(run) := tr:get-run($runid, $converter, $worker),
      $file-logs := tr:get-job-messages($run,$converter)
  return 
    if (xs:boolean($authed/@allowed))
    then element log-messages {$file-logs}
    else api:error(i18n:val($authed/messages/text(),$lang))
};

declare
  %rest:GET
  %rest:path("/api/{$lang}/worker/{$worker-id}/converter/{$converter-id}/runs/{$runid}/files")
  %output:method("xml")
function api:get-converter-run-file-results($worker-id as xs:string, $converter-id as xs:string, $runid as xs:string ,$lang as xs:string){
  let $headers as map(xs:string, xs:string*):= request:header-map(),
      $authed as element(auth):= api:auth($headers),
      $username := $authed/username,
      $worker as element(worker)? := tr:get-worker($worker-id),
      $converter as element(converter)? := tr:get-worker-converter($converter-id),
      $run as element(run) := tr:get-run($runid, $converter, $worker),
      $files := tr:get-result-files($run,$converter)
  return 
    if (xs:boolean($authed/@allowed))
    then element result-files {$files}
    else api:error(i18n:val($authed/messages/text(),$lang))
};

declare
  %rest:GET
  %rest:path("/api/{$lang}/worker/{$worker-id}/converter/{$converter-id}/runs/{$runid}/cancel")
  %output:method("xml")
function api:get-converter-stop-run($worker-id as xs:string, $converter-id as xs:string, $runid as xs:string ,$lang as xs:string){
  let $headers as map(xs:string, xs:string*):= request:header-map(),
      $authed as element(auth):= api:auth($headers),
      $username := $authed/username,
      $worker as element(worker)? := tr:get-worker($worker-id),
      $converter as element(converter)? := tr:get-worker-converter($converter-id),
      $run as element(run)? := tr:get-run($runid, $converter),
      $stop := tr:stop-run($run, $username, $converter, $worker)
  return 
    if (xs:boolean($authed/@allowed))
    then element result{$stop}
    else api:error(i18n:val($authed/messages/text(),$lang))
};

declare
  %rest:GET
  %rest:path("/api/{$lang}/worker/{$worker-id}/converter/{$converter-id}/runs/{$runid}/download/{$filename}")
function api:get-converter-runs-download($worker-id as xs:string, $converter-id as xs:string, $runid as xs:string ,$lang as xs:string, $filename as xs:string){
  let $headers as map(xs:string, xs:string*):= request:header-map(),
      $authed as element(auth):= api:auth($headers),
      $username := $authed/username,
      $worker as element(worker)? := tr:get-worker($worker-id),
      $converter as element(converter)? := tr:get-worker-converter($converter-id),
      $run as element(run)? := tr:get-run($runid, $converter),
      $data as xs:base64Binary? := tr:get-file($run, $filename, $converter, $worker)
  return 
    if (xs:boolean($authed/@allowed))
    then $data
    else element error {'File not found!'}
};

declare
  %rest:GET
  %rest:path("/api/error")
  %rest:query-param("message", "{$message}")
  %output:method("xml")
  %output:html-version('5')
function api:error($message as xs:string*){
  element error {$message}
};

declare
  %rest:GET
  %rest:path("/api/{$lang}/token/new")
  %output:method("xml")
function api:get-new-token($lang as xs:string){
  let $headers as map(xs:string, xs:string*):= request:header-map(),
      $auth := api:auth($headers, true())
  return
    if (xs:boolean($auth/@allowed))
    then u:get-new-token($auth/username)
    else element error {i18n:val('login-failed',$lang)}
}; 

declare
  %rest:GET
  %rest:path("/api/{$lang}/token/valid")
  %output:method("xml")
function api:token-valid($lang as xs:string){
  let $headers as map(xs:string, xs:string*):= request:header-map(),
      $auth := api:auth($headers, true())
  return
    if (xs:boolean($auth/@allowed))
    then element result {true()}
    else element error {i18n:val('login-failed',$lang)}
}; 

declare
  %rest:GET
  %rest:path("/api/{$lang}/token/clear")
  %output:method("xml")
function api:clear-tokens($lang as xs:string){
  let $headers as map(xs:string, xs:string*):= request:header-map(),
      $authed as element(auth):= api:auth($headers),
      $username as xs:string := $authed/username
  return
    if ($authed/@allowed)
    then u:clear-tokens($username)
    else api:error(i18n:val($authed/messages/text(),$lang))
}; 

declare
  %rest:POST
  %rest:path("/api/{$lang}/users/new")
  %rest:form-param("password","{$password}")
  %rest:form-param("username","{$username-to-create}")
  %output:method("html")
  %output:html-version('5')
function api:user-new($lang,$username-to-create,$password){
  let $headers as map(xs:string, xs:string*):= request:header-map(),
      $authed as element(auth):= api:auth($headers),
      $username as xs:string := $authed/username,
      $right := 'u:mgmt',
      $can-do := api:can-do($right, $username),
      $do-update := if ($can-do) then u:new-user($username-to-create, $password) else (),
      $log := if ($can-do) then hf:log('create new user: ' ||$username-to-create)
  return $do-update
};

declare
  %rest:GET
  %rest:path("/api/{$lang}/users")
  %output:method("html")
  %output:html-version('5')
function api:user-get($lang){
  let $headers as map(xs:string, xs:string*):= request:header-map(),
      $authed as element(auth):= api:auth($headers),
      $username as xs:string := $authed/username,
      $user := u:users($username),
      $right := 'u:mgmt',
      $can-do := api:can-do($right, $username),
      $get := if ($can-do) then u:users()
  return $get
};

declare
  %rest:GET
  %rest:path("/api/{$lang}/users/{$username-to-get}")
  %output:method("html")
  %output:html-version('5')
function api:user-get($lang,$username-to-get){
  let $headers as map(xs:string, xs:string*):= request:header-map(),
      $authed as element(auth):= api:auth($headers),
      $username as xs:string := $authed/username,
      $user := u:users($username),
      $right := 'u:mgmt',
      $can-do := api:can-do($right, $username, $username-to-get),
      $get := if ($can-do) then u:users($username-to-get)
  return $get
};

declare
  %rest:GET
  %rest:path("/api/{$lang}/users/{$username-to-delete}/delete")
  %output:method("html")
  %output:html-version('5')
function api:user-new($lang,$username-to-delete){
  let $headers as map(xs:string, xs:string*):= request:header-map(),
      $authed as element(auth):= api:auth($headers),
      $username as xs:string := $authed/username,
      $right := 'u:mgmt',
      $can-do := api:can-do($right, $username, $username-to-delete),
      $do-update := if ($can-do) then u:delete-user($username-to-delete) else (),
      $log := if ($can-do) then hf:log('delete user: ' ||$username-to-delete)
  return $do-update
};

declare %private function api:converter($converter-id as xs:string, $username as xs:string, $lang as xs:string) {
  let $right :=  $converter-id || ':convert',
      $converter := if (api:can-do($right, $username)) then conv:get($converter-id) else element error {i18n:val('not-allowed-message', $lang)}
  return $converter
};

declare %private function api:converter($username as xs:string, $lang as xs:string) {
  let $converter := conv:get-all(),
      $user := u:users($username),
      $filtered :=
        for $conv in $converter
        where api:can-do($conv/@id || ':convert', $username) 
        return $conv
  return $converter
};

declare %private function api:status() {
  element status {
    attribute status {'running'},
    tr:system-cpu(),
    tr:system-memory()
  }
};

declare %private function api:auth($headers as map(xs:string, xs:string*)?, $allowed-override as xs:boolean? := false()) as element(auth) {
  if ($api:is-worker)
  then
    let $username := $headers?username otherwise 'not-found'
    return
      element auth {
        attribute allowed {true()},
        element username { $username }
      }
  else 
    if (not(exists($headers)) or not(exists($headers?Authorization)))
    then
      element auth {
        attribute allowed {false()},
        element messages {'no-cred-message'}
      }
    else
      let $auth-header as xs:string+ := $headers?Authorization => tokenize(' '),
          $auth := $auth-header[2],
          
          $result := 
            element auth {
              switch ($auth-header[1])
                case 'Basic' return
                  let $auth-decoded := bin:decode-string(xs:base64Binary($auth)) => tokenize(':'),
                      $allow-use := xs:boolean($api:config/allow-basic-auth/text()) or $allowed-override
                  return (
                    attribute allowed {if ($allow-use) then u:validate-password($auth-decoded[1],$auth-decoded[2]) else false()},
                    element username {$auth-decoded[1]},
                    element messages {'basic-auth-disabled'}[not($allow-use)]
                    )
                case 'Bearer' return
                  let $token := $auth,
                      $allow-use := xs:boolean($api:config/allow-bearer-auth/text()) or $allowed-override
                  return (
                    attribute allowed {if (xs:boolean($api:config/allow-bearer-auth/text()) or $allowed-override) then u:validate-token($token) else false()},
                    element username {u:username-for-token($token)},
                    element messages {'bearer-auth-disabled'}[not($allow-use)],
                    element messages {'token-invalid'}[$allow-use]
                    )
                default return attribute allowed {false()}
            }
      return $result
};

declare function api:can-do($right,$username,$owner := ()) {
  let $user := u:users($username)
  return if ($api:is-worker)then true() else tr:can-do($user, $right, $owner)
};