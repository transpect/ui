module namespace api = 'http://le-tex.de/api';

import module namespace conv = 'http://le-tex.de/converter' at 'converter.xqm';
import module namespace config = 'http://le-tex.de/config' at 'config.xqm';
import module namespace hf = 'http://le-tex.de/helper-functions' at 'helper-functions.xqm';
import module namespace i18n = 'http://le-tex.de/i18n' at 'i18n.xqm';
import module namespace make = 'http://le-tex.de/make' at 'make.xqm';
import module namespace u = 'http://le-tex.de/user' at 'user.xqm';
import module namespace ns = 'http://le-tex.de/namespaces' at '/opt/basex/webapp/transpectui/namespaces.xqm';

declare variable $api:config := $config:file/configurations/configuration/api;

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
  %rest:path("/api")
  %output:method("xml")
function api:overview(){
  api:overview('en')
}; 

declare
  %rest:GET
  %rest:path("/api/{$lang}/converter")
  %output:method("xml")
function api:get-converters($lang as xs:string){
  let $headers as map(xs:string, xs:string*):= request:header-map(),
      $authed := api:auth($headers),
      $username := $authed/username
  return 
    if (xs:boolean($authed/@allowed))
    then api:converter($username, $lang)
    else api:error(i18n:val($authed/messages/text(),$lang))
};

declare
  %rest:GET
  %rest:path("/api/{$lang}/converter/{$converter-id}")
  %output:method("xml")
function api:get-converter($converter-id as xs:string, $lang as xs:string){
  let $headers as map(xs:string, xs:string*):= request:header-map(),
      $authed as element(auth):= api:auth($headers),
      $username := $authed/username
  return 
    if (xs:boolean($authed/@allowed))
    then api:converter($username, $converter-id, $lang)
    else api:error(i18n:val($authed/messages/text(),$lang))
};

declare
  %rest:POST
  %rest:path("/api/{$lang}/converter/{$converter-id}")
  %rest:form-param('file', '{$file}')
  %output:method("xml")
function api:upload-file($file as map(xs:string, xs:base64Binary), $converter-id as xs:string, $lang as xs:string){
  let $headers as map(xs:string, xs:string*):= request:header-map(),
      $authed as element(auth):= api:auth($headers),
      $username := $authed/username,
      $text-params := map:remove(request:parameter-map(),('upload_file_uploaded_data','file')),
      $user := u:users($username),
      $right := $converter-id || ':convert',
      $is-allowed := (u:can-do($user, $right) and xs:boolean($authed/@allowed)),
      $converter := conv:get($converter-id),
      $run as (element(error)|element(run)) :=
        if ($is-allowed)
        then make:start-target-run('conversion', $converter, $text-params, $file, $username)
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
      $username := $authed/username,
      $runs := make:get-runs(),
      $user := u:users($username),
      $allowed-runs := 
        for $runid in map:keys($runs)
        where make:allowed($username,$runs?$runid)
        return $runid,
      $running-runs :=
        for $runid in $allowed-runs
        where xs:boolean($runs?$runid?status eq 'running')
        return $runid,
      $finished-runs :=
        for $runid in $allowed-runs
        where not(xs:boolean($runs?$runid?status = ('pending','running')))
        return $runid,
      $pending-runs :=
        for $runid in $allowed-runs
        where xs:boolean($runs?$runid?status eq 'pending')
        return $runid,
      $result := (
        for $runid in $pending-runs
        let $run as map(*) :=$runs?$runid
        order by xs:dateTime($run?start) descending
        return element run { attribute runid {$runid}, hf:map-to-xml($run)},
        for $runid in $running-runs
        let $run as map(*) :=$runs?$runid
        order by xs:dateTime($run?start) descending
        return element run { attribute runid {$runid}, hf:map-to-xml($run)},
        for $runid in $finished-runs
        let $run as map(*) :=$runs?$runid
        order by xs:dateTime($run?start) descending
        return element run { attribute runid {$runid}, hf:map-to-xml($run)}
      )
  return 
    if (xs:boolean($authed/@allowed))
    then element runs {$result}
    else api:error(i18n:val($authed/messages/text(),$lang))
};

declare
  %rest:GET
  %rest:path("/api/{$lang}/converter/{$converter-id}/runs/{$runid}")
  %output:method("xml")
function api:get-converter-runs($converter-id as xs:string, $runid as xs:string ,$lang as xs:string){
  let $headers as map(xs:string, xs:string*):= request:header-map(),
      $authed as element(auth):= api:auth($headers),
      $username := $authed/username,
      $run-info as map(*) := make:get-run($runid),
      $out-path := $run-info?params[matches(.,'OUT_DIR')] ! tokenize(.,'=')[2],
      $result-files :=
        for $file in file:list($out-path)
        where not(matches($file,'/$')) and not(matches($file, '\.pid$|\.stdout$'))
        return {'name': normalize-space($file), 'path': $out-path || normalize-space($file)},
      $result-download-urls := 
        for $file in $result-files
        let $extention := ($file?name => tokenize('[\./]'))[last()]
        return
          element result-files {
            attribute name {($file?name => tokenize('/'))[last()]},
            attribute href {config:url('/api/' || $lang || '/converter/' || $converter-id ||'/runs/' || $runid || '/download/' || $file?name)}
          }
  return 
    if (xs:boolean($authed/@allowed))
    then element run {attribute runid {$runid}, hf:map-to-xml($run-info), $result-download-urls}
    else api:error(i18n:val($authed/messages/text(),$lang))
};

declare
  %rest:GET
  %rest:path("/api/{$lang}/converter/{$converter-id}/runs/{$runid}/download/{$filename}")
function api:get-converter-runs-download($converter-id as xs:string, $runid as xs:string ,$lang as xs:string, $filename as xs:string){

  let $run-info as map(*) := make:get-run($runid),
      $out-path := $run-info?params[matches(.,'OUT_DIR')] ! tokenize(.,'=')[2],
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
      $user := u:users($username),
      $right := 'u:mgmt',
      $can-do := u:can-do($user, $right),
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
      $can-do := u:can-do($user, $right),
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
      $can-do := u:can-do($user, $right, $username-to-get),
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
      $user := u:users($username),
      $right := 'u:mgmt',
      $can-do := u:can-do($user, $right, $username-to-delete),
      $do-update := if ($can-do) then u:delete-user($username-to-delete) else (),
      $log := if ($can-do) then hf:log('delete user: ' ||$username-to-delete)
  return $do-update
};

declare %private function api:converter($converter-id as xs:string, $username as xs:string, $lang as xs:string) {
  let $user := u:users($username),
      $converter := if (u:can-do($user, $converter-id || ':convert')) then conv:get($converter-id) else element error {i18n:val('not-allowed-message', $lang)}
  return $converter
};

declare %private function api:converter($username as xs:string, $lang as xs:string) {
  let $converter := conv:get-all(),
      $user := u:users($username),
      $filtered :=
        for $conv in $converter
        where u:can-do($user, $conv/@id || ':convert') 
        return $conv
  return $converter
};

declare %private function api:auth($headers as map(xs:string, xs:string*)?, $allowed-override as xs:boolean? := false()) as element(auth) {
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
                let $auth-decoded := convert:binary-to-string(xs:base64Binary($auth)) => tokenize(':'),
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