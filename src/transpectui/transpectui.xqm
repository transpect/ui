module namespace ui  = 'http://le-tex.de/transpectui';
import module namespace conv = 'http://le-tex.de/converter' at 'converter.xqm';
import module namespace config = 'http://le-tex.de/config' at 'config.xqm';
import module namespace hf = 'http://le-tex.de/helper-functions' at 'helper-functions.xqm';
import module namespace i18n = 'http://le-tex.de/i18n' at 'i18n.xqm';
import module namespace make = 'http://le-tex.de/make' at 'make.xqm';
import module namespace u = 'http://le-tex.de/user' at '/opt/basex/webapp/transpectui/user.xqm';

declare function ui:check($right as xs:string?, $lang as xs:string, $return-url as xs:string?, $owner as xs:string? := ()){
  let $is-logged-in := exists(session:get('username')),
      $is-allowed := ui:check-only($right, $owner),
      $log := hf:log($right || ': ' || session:get('username') || ' => ' || $is-allowed,'CHECK')
  return
    if ($is-logged-in)
    then if ($is-allowed)
         then ()
         else web:redirect(config:url( '/' ||$lang || '/' || 'error?url=' || '/' || $lang || $return-url || '&amp;message=' || i18n:val('not-allowed-message',$lang)))
    else web:redirect(config:url( '/' ||$lang || '/' || 'login?url=' || '/' || $lang || $return-url || '&amp;message=' || i18n:val('not-logged-in-message',$lang)))
};

declare function ui:check-only($right as xs:string?, $owner as xs:string? := ()){
  let $username := session:get('username'),
      $token := session:get('token'),
      $is-allowed := u:check($username, $token, $right) or ($owner eq session:get('username'))
  return $is-allowed
};

declare
  %rest:GET
  %rest:path("/{$lang}/converter")
  %output:method("html")
  %output:html-version('5')
function ui:converter-list($lang as xs:string){
  let $right := 'tr:list',
      $title := 'TranspectUI',
      $header := request:header-map(),
      $converters as element(converter)* := conv:get-all(),
      $url := '/converter',
      $context := map {'title': $title, 'lang': $lang, 'url':$url, 'return-url':$url}
  return
    (
      if (count($converters) eq 1)
      then
        web:redirect(config:url('/' || $lang || '/converter/' || $converters[1]/xs:string(@id)))
      else (
        ui:check($right, $lang, $url),
        element html {
          config:get-html-head($context),
          element body {
            config:get-html-header($context),
            element div {
              attribute class {'well'},
              for $converter in $converters
              let $allowed := ui:check-only($converter/@id || ':convert')
              return
                ui:create-anchor($converter/xs:string(@name), config:url('/' || $lang || '/converter/' || $converter/xs:string(@id)), 'block', $allowed)
            }
          }
        }
      )
    )
};

declare
  %rest:GET
  %rest:path("/{$lang}/converter/{$converter-id}")
  %output:method("html")
  %output:html-version('5')
function ui:converter-page($converter-id as xs:string, $lang as xs:string){
  let $converter := conv:get($converter-id),
      $title := $converter/xs:string(@name),
      $parameters := $converter/inputs/*,
      $url := '/converter/' || $converter-id,
      $context := map {'title': $title, 'lang': $lang, 'return-url':'/converter/', 'url':$url},
      $right := $converter-id || ':convert'
  return
    (
      ui:check($right, $lang, $url),
      element html {
        config:get-html-head($context),
        element body {
          config:get-html-header($context),
          element div {
            attribute class {'well'},
            hf:create-anchor(config:url('/' || $lang || '/converter/' || $converter-id || '/runs'),i18n:val('prev-conversions',$lang))
          },
          element div {
            attribute class {'well'},
            element form {
              attribute action {config:url('/' || $lang || '/converter/' || $converter-id || '/convert')},
              attribute method {'POST'},
              attribute enctype {"multipart/form-data"},
              for $p in $parameters
              return hf:parameter-to-html($p, $lang),
              element form-group{
                element label {
                  i18n:val("upload",$lang)
                },
                element input {
                  attribute type {'text'},
                  attribute required {''},
                  attribute readonly {''},
                  attribute name {'file-name'},
                  attribute id {'file-name'},
                  attribute class {'form-control invalid'},
                  attribute onclick {"document.querySelector('#upload_file_uploaded_data').click();document.querySelector('#submit-to-conversion').classList.remove('disabled');"},
                  attribute placeholder {i18n:val("select-file",$lang)},
                  attribute autocomplete {'off'}
                },
                element input {
                  attribute type {'file'},
                  attribute id {'upload_file_uploaded_data'},
                  attribute name {'upload_file_uploaded_data'},
                  attribute class {'hidden'}
                },
                element button {
                  attribute id {'submit-to-conversion'},
                  attribute disabled {},
                  attribute class {'primary-btn disabled'},
                  attribute type {'submit'},
                  i18n:val("submit-file",$lang)
                }
              }
            }
          }
        }
      }
    )
};

declare
  %rest:GET
  %rest:path("/{$lang}/converter/{$converter-id}/runs")
  %output:method("html")
  %output:html-version('5')
function ui:converter-runs($converter-id as xs:string, $lang as xs:string){
  let $runs := make:get-runs(),
      $username := session:get('username'),
      $token := session:get('token'),
      $title := i18n:val('conversions',$lang),
      $url := '/converter/' || $converter-id || '/runs',
      $return-url := '/converter/' || $converter-id,
      $right := $converter-id || ':conversions',
      $context := map {'title': $title, 'lang': $lang, 'return-url':$return-url, 'url':'/converter/'|| $converter-id || '/runs'},
      $allowed-runs := 
        for $runid in map:keys($runs)
        where 
          (ui:check-only($converter-id || ':' || 'convertions')
             or $runs?$runid?username eq $username
             or (
              let $my-groups := u:groups($username),
                  $run-groups := if ($runs?$runid?username) then u:groups($runs?$runid?username) else (),
                  $needed-right := $converter-id || ':' || 'runs',
                  $is-allowed := u:check($username, $token, $needed-right),
                  $group-matches := $my-groups = $run-groups
              return $is-allowed and $group-matches
             )
          )
        return $runid,
      (:$log := admin:write-log(string-join($allowed-runs,',') || ':','ALLOWED'),:)
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
        return $runid
  return(
    ui:check($right, $lang, $return-url),
    element html {
      config:get-html-head($context),
      element body {
        config:get-html-header($context),
        element div {
          attribute class {'well'},
          element div {
            attribute class {'date spacious'},
            i18n:val('called',$lang) || ': ' || hf:format-dateTime(current-dateTime())
          },
          element div {
            attribute class {'well'},
            i18n:val('pending-conversions',$lang) || ':',
            if (count($pending-runs) eq 0)
            then make:empty-run-info('empty-pending',$lang)
            else
              for $runid in $pending-runs
              let $run as map(*) :=$runs?$runid
              order by xs:dateTime($run?start) descending
              return make:run-info-display($runid, $run, $lang, $converter-id, $context)
          },
          element div {
            attribute class {'well'},
            i18n:val('running-conversions',$lang) || ':',
            if (count($running-runs) eq 0)
            then make:empty-run-info('empty-running',$lang)
            else
              for $runid in $running-runs
              let $run as map(*) :=$runs?$runid
              order by xs:dateTime($run?start) descending
              return make:run-info-display($runid, $run, $lang, $converter-id, $context)
          },
          element div {
            attribute class {'well'},
            i18n:val('finished-conversions',$lang) || ':',
            if (count($finished-runs) eq 0)
            then make:empty-run-info('empty-finished',$lang)
            else
              for $runid in $finished-runs
              let $run as map(*) :=$runs?$runid
              order by xs:dateTime($run?start) descending
              return make:run-info-display($runid, $run, $lang, $converter-id, $context)
          }
        }
      }
    }
  )
};

declare
  %rest:POST
  %rest:path("/{$lang}/converter/{$converter-id}/convert")
  %rest:form-param('upload_file_uploaded_data', '{ $file }')
  %output:method("html")
  %output:html-version('5')
function ui:converter-convert($converter-id as xs:string, $file as map(xs:string, xs:base64Binary), $lang as xs:string){
  let $params := request:parameter-map(),
      $text-params := map:remove(request:parameter-map(),'upload_file_uploaded_data'),
      $converter as element(converter) := conv:get($converter-id),
      $run as element(run) := make:start-target-run('conversion', $converter, $text-params, $file, session:get('username')) 
  return if ($run/error)
         then web:redirect(config:url('/' || $lang ||'/converter/' || $converter-id || '/error/' || $run/error)) 
         else web:redirect(config:url('/' || $lang ||'/converter/' || $converter-id || '/runs/'   || $run/id))
};

declare
  %rest:GET
  %rest:query-param("url", "{$return-url}")
  %rest:path("/{$lang}/converter/{$converter-id}/runs/{$runid}/cancel")
function ui:stop-run-frontend($runid, $lang, $converter-id, $return-url){
  let $run := make:get-run($runid),
      $is-allowed := true(),
      $cancel := if ($is-allowed) then make:stop-run($runid) else ()
  return web:redirect(config:url($return-url))
};

declare
  %rest:GET
  %rest:path("/{$lang}/converter/{$converter-id}/runs/{$runid}")
  %output:method("html")
  %output:html-version('5')
function ui:log($converter-id as xs:string, $runid as xs:string, $lang as xs:string){
  let $converter as element(converter) := conv:get($converter-id),
      $run-info as map(*) := make:get-run($runid),
      $status as xs:string := $run-info?status,
      $is-running as xs:boolean := $status eq 'running' or $status eq 'pending',
      $parameters as xs:string* := $run-info?params,
      $logs as xs:string* := make:get-logs($runid),
      $short-status := switch ($status)
                        case 'running' return '▶️'
                        case 'pending' return '⏳'
                        case 'stopped' return '✔️'
                        default return '-',
      $title as xs:string? := $run-info?filename,
      $start as xs:dateTime := xs:dateTime($run-info?start),
      $end as xs:dateTime? := if (exists($run-info?end)) then xs:dateTime($run-info?end) else (),
      $subtitle as xs:string? := hf:format-dateTime(xs:dateTime($run-info?start)) || (" - " || hf:format-dateTime($end) || ' (' || hf:format-duration($end - $start) || ')')[exists($end)],
      $refresh := if ($is-running) then 5 else (),
      $url := '/converter/' || $converter-id || '/runs/' || $runid,
      $context := map {'lang': $lang, 'title': $title, 'status': $short-status || ' ', 'refresh': $refresh, 'return-url': '/converter/' || $converter-id, 'url': $url , 'subtitle':$subtitle},
      $log-dir := (($run-info?file => tokenize('/'))[position() ne last()] => string-join('/')) || '/debug/status',
      $logs := make:get-file-logs($run-info?file),
      $job-results := make:store-job-messages($runid),
      $post-conv-actions := conv:get-post-conv-actions($converter),
      $out-path := $run-info?params[matches(.,'OUT_DIR')] ! tokenize(.,'=')[2],
      $result-files :=
        for $file in file:list($out-path)
        where not(matches($file,'/$')) and not(matches($file, '\.pid$|\.stdout$'))
        return {'name': normalize-space($file), 'path': $out-path || normalize-space($file)}
  return (
    ui:check('', $lang, $url),
    element html {
      config:get-html-head($context),
      element body {
        config:get-html-header($context),
        element div {
          element div {
            attribute class {'well'},
            element h3 {i18n:val($status,$lang)},
            hf:create-anchor(config:url('/' ||$lang || '/converter/' || $converter-id || '/runs/' || $runid || '/cancel' || '?url=/' || $lang || $url), i18n:val("cancel",$lang))[not($run-info?status = ('stopped','canceled'))]
          },
          element details {
            attribute class {'make-parameters well'},
            element summary {'Parameters'},
            element ul {
              for $p in $parameters
              return
                element li {
                  $p
                }
            }
          },
          element details {
            attribute class {'make-logs well'},
            if ($status eq 'running') then attribute open {} else (),
            element summary {i18n:val('logs',$lang)},
            for $log at $index in $logs
            return element div {
              attribute class {'log-entry'},
              element span {attribute class {'index'}, $index},
              element span {attribute class {'time'}, hf:format-dateTime($log?time)},
              element span {$log?text}
            }
          },
        element details {
          attribute class {'well'},
          if ($status eq 'stopped') then attribute open {} else (),
          element summary {i18n:val('results',$lang)},
          for $file in $result-files
          let $extention := ($file?name => tokenize('[\./]'))[last()],
              $show-direct as xs:boolean := $extention = ('xhtml','html')
          return element div {
            attribute class {'line d-flex'},
            element div {
              attribute class {'filename'},
              if ($show-direct)
              then
                element a {
                  attribute href {config:url('/runs/' ||$runid || '/show/' || $file?name)},
                  attribute target {'_blank'},
                  $file?name}
              else
                element a {
                  attribute href {config:url('/runs/' ||$runid || '/download/' || $file?name)},
                  attribute target {'_blank'},
                  attribute download {$file?name},
                  $file?name}},
            element div {
              attribute class {'actions'},
              for $action in $post-conv-actions
              where matches($file?name, $action/xs:string(@regex))
              return
                element input{
                  attribute type {'button'},
                  attribute value {$action/xs:string(@message)},
                  attribute data-href {config:url(string-join(('/run',$runid, $file?name, 'action', $action/xs:string(@target)),'/'))}
                }
            }
          }
        },
        element details {
          attribute class {'well'},
          element summary {i18n:val('run',$lang)},
          element div {
            attribute class {'overflow'},
            for $m  at $index in $job-results
            return element div {
              attribute class {'log-entry'},
              element span {attribute class {'index'}, $index},
              element span {$m}
            }
          }
        }
        }
      }
    }
  )
};

declare
  %rest:GET
  %rest:path("/run/{$runid}/download/{$filename}")
function ui:download($runid, $filename) {
  let $outpath := make:get-run($runid)?params[matches(.,'OUT_DIR')] ! tokenize(.,'=')[2],
      $filepath := $outpath || $filename,
      $filesize := file:size($filepath),
      $format := $filename ! tokenize('.')[last()],
      $data := file:read-binary($filepath)
  return
      (web:response-header(
        map { 'media-type': 'application/' || $format},
        map { 'Content-Disposition': 'attachement;filename=' || $filename,
              'Content-Length': $filesize }),
       $data)
};

declare
  %rest:GET
  %rest:path("/run/{$runid}/show/{$filename}")
  %output:method("html")
  %output:html-version('5')
function ui:show($runid, $filename) {
  if (ui:check-only(''))
  then
    let $outpath := make:get-run($runid)?params[matches(.,'OUT_DIR')] ! tokenize(.,'=')[2],
        $filepath := $outpath || $filename,
        $filesize := file:size($filepath),
        $extention := ($filename => tokenize('[\./]'))[last()],
        $show-direct as xs:boolean := $extention = ('xhtml','html'),
        $format := $filename ! tokenize('.')[last()],
        $data := if ($show-direct) then doc($filepath) else file:read-binary($filepath),
        $log := admin:write-log($filename || ': ' || $extention || ': ' || xs:string($show-direct))
    return if ($show-direct) then $data else web:error('415','Das Dokument kann nicht angezeigt werden.')
  else web:error(403, 'You are not allowed to access this file.')
};

declare
  %rest:GET
  %rest:path("/run/{$runid}/{$filename}/action/{$action-name}")
function ui:post-conversion-action($runid, $filename, $action-name as xs:string) {
  let $outpath := make:get-run($runid)?params[matches(.,'OUT_DIR')] ! tokenize(.,'=')[2],
      $filepath := $outpath || $filename,
      $converter := make:get-converter($runid),
      $actions := conv:get-post-conv-actions($converter),
      $action := $actions[@target eq $action-name],
      $start :=
        if ($action)
        then make:start-target($action-name, $converter, $filepath, $runid, make:format-target-parameters(map {'IN_FILE': $filepath}))
        else 'No action specified'
  return $start
};

declare 
  %rest:GET
  %rest:path("/{$lang}/converter/{$converter-id}/error/{$error-message}")
  %output:method("html")
  %output:html-version('5')
function ui:error($error-message, $converter-id, $lang) {
  let $converter := conv:get($converter-id),
      $title := $converter/xs:string(@name),
      $context := map {'title': $title, 'lang': $lang, 'url':'/converter/' || $converter-id || '/error/' || $error-message, 'return-url':'/converter/' || $converter-id}
  return
    element html {
        config:get-html-head($context),
        element body {
          config:get-html-header($context),
          element div {
            attribute class {'error well'},
            $error-message
          }
        }
      }
}; 

declare
  %rest:GET
  %rest:path("/{$lang}/login")
  %rest:query-param("url", "{$return-url}")
  %rest:query-param("message", "{$message}")
  %output:method("html")
  %output:html-version('5')
function ui:login-frontend($lang as xs:string, $return-url as xs:string?, $message as xs:string?){
  let $title := 'TranspectUI Login',
      $url := '/login',
      $context := map {'title': $title, 'lang': $lang, 'url':$url, 'return-url': ($return-url, $url)[1]}
  return
    element html {
      config:get-html-head($context),
      element body {
        config:get-html-header($context),
        element div {
              attribute class {'well'},
              element div {
                attribute class {'red'},
                $message
              }
            }[$message],
        element div {
          attribute class {'well'},
          element form {
            attribute action {'do-login'},
            attribute method {'POST'},
            
            hf:parameter-to-html(<input type="text" name-de="Username" name-en="Username" p-name="username" required=""/>,$lang),
            hf:parameter-to-html(<input type="password" name-de="Passwort" name-en="Password" p-name="password" required=""/>,$lang),
            element input {
              attribute type {'hidden'},
              attribute name {'url'},
              attribute value {$return-url}
            },
            element form-group{
              element label {},
              element button {
                  attribute id {'submit-login'},
                  attribute class {'primary-btn'},
                  attribute type {'submit'},
                  i18n:val("login",$lang)
              }
            }
          }
        }
      }
    }
};

declare
  %rest:POST
  %rest:path("/{$lang}/do-login")
  %rest:form-param("url", "{$url}")
  %rest:form-param("username", "{$username}")
  %rest:form-param("password", "{$password}")
function ui:do-login($lang as xs:string, $url as xs:string?, $username as xs:string?, $password as xs:string?){
        let $login as (element(token)|element(error)) := u:get-token($username, $password),
      $is-error := $login/self::error
  return
    if ($is-error) 
    then web:redirect('error?url=' || 'login&amp;message=' || i18n:val('login-failed',$lang))
    else (
      session:set('token', $login/self::token/text()),
      session:set('timestamp', current-dateTime()),
      session:set('username', $username),
      if ($url) then web:redirect($url) else web:redirect('converter')
    )
};

declare
  %rest:GET
  %rest:path("/{$lang}")
  %output:method("html")
  %output:html-version('5')
function ui:default($lang) {
  web:redirect(config:url('/' || $lang || '/converter' ))
};

declare
  %rest:GET
  %rest:path("/")
  %output:method("html")
  %output:html-version('5')
function ui:default-2() {
  web:redirect(config:url('/de/converter' ))
};

declare
  %rest:GET
  %rest:path("/{$lang}/error")
  %rest:query-param("url", "{$return-url}")
  %rest:query-param("message", "{$message}")
  %output:method("html")
  %output:html-version('5')
function ui:error-frontend($lang as xs:string, $return-url as xs:string?, $message as xs:string?){
  let $title := 'TranspectUI Error',
      $url := '/error',
      $context := map {'title': $title, 'lang': $lang, 'url':$url, 'return-url': $return-url}
  return
    element html {
      config:get-html-head($context),
      element body {
        config:get-html-header($context),
        element div {
          attribute class {'well'},
          element div {
            attribute class {'red'},
            $message
          },
          element div {
            ui:create-anchor(i18n:val('back',$lang), config:url($return-url))
          }
        }
      }
    }
};

declare
  %rest:GET
  %rest:path("/{$lang}/users/{$username-to-update}/roles/add/{$role}")
  %rest:query-param("url","{$return-url}")
  %output:method("html")
  %output:html-version('5')
function ui:user-add-role($lang as xs:string, $username-to-update as xs:string, $role as xs:string, $return-url as xs:string?){
  let $right := 'u:mgmt',
      $can-do := ui:check-only($right, $lang),
      $log := hf:log('adding role ' || $role || ' to ' || $username-to-update || ' by ' || session:get('username') || '(' || $can-do || ')','CHECK'),
      $do-update := if ($can-do) then u:add-role($username-to-update, $role) else ()
  return web:redirect(config:url('/' || $lang || $return-url))
};

declare
  %rest:GET
  %rest:path("/{$lang}/users/{$username-to-update}/roles/remove/{$role}")
  %rest:query-param("url","{$return-url}")
  %output:method("html")
  %output:html-version('5')
function ui:user-remove-role($lang, $username-to-update, $role, $return-url){
  let $right := 'u:mgmt',
      $can-do := ui:check-only($right, $username-to-update),
      $do-update := if ($can-do) then u:delete-role($username-to-update, $role) else ()
  return web:redirect(config:url('/' || $lang || $return-url))
};

declare
  %rest:POST
  %rest:path("/{$lang}/users/{$username-to-update}/password/reset")
  %rest:query-param("url","{$return-url}")
  %rest:form-param("password","{$password}")
  %output:method("html")
  %output:html-version('5')
function ui:user-reset-password($lang,$username-to-update,$password, $return-url){
  let $right := 'u:mgmt',
      $can-do := ui:check($right, $lang, $return-url, $username-to-update),
      $do-update := if ($can-do) then u:set-password($username-to-update, $password) else ()
  return web:redirect(config:url('/' || $lang ||$return-url))
};

declare
  %rest:POST
  %rest:path("/{$lang}/users/new")
  %rest:query-param("url","{$return-url}")
  %rest:form-param("password","{$password}")
  %rest:form-param("username","{$username-to-create}")
  %output:method("html")
  %output:html-version('5')
function ui:user-new($lang,$username-to-create,$password, $return-url){
  let $right := 'u:mgmt',
      $can-do := ui:check-only($right),
      $do-update := if ($can-do) then u:new-user($username-to-create, $password) else (),
      $log := if ($can-do) then hf:log('create new user: ' ||$username-to-create)
  return web:redirect(config:url('/' || $lang ||$return-url))
};
declare
  %rest:GET
  %rest:path("/{$lang}/users/{$username-to-delete}/delete")
  %rest:query-param("url","{$return-url}")
  %output:method("html")
  %output:html-version('5')
function ui:user-new($lang,$username-to-delete, $return-url){
  let $right := 'u:mgmt',
      $can-do := ui:check-only($right,$username-to-delete),
      $do-update := if ($can-do) then u:delete-user($username-to-delete) else (),
      $log := if ($can-do) then hf:log('delete user: ' ||$username-to-delete)
  return web:redirect(config:url('/' || $lang ||$return-url))
};

declare
  %rest:GET
  %rest:path("/{$lang}/users/{$username-to-update}/sessions/{$id}/close")
  %rest:query-param("url","{$return-url}")
  %output:method("html")
  %output:html-version('5')
function ui:user-cancel-session($lang,$username-to-update,$id,$return-url){
  let $right := 'u:mgmt',
      $can-do := ui:check($right, $lang, $return-url, $username-to-update),
      $do-update := if ($can-do) then ui:close-session($id)
  return web:redirect(config:url('/' || $lang ||$return-url))
};

declare
  %rest:GET
  %rest:path("/{$lang}/users/{$username-to-update}")
  %rest:query-param("url","{$return-url}")
  %output:method("html")
  %output:html-version('5')
function ui:user($lang, $username-to-update, $return-url){
  let $title := i18n:val('user-preferences',$lang),
      $username := session:get('username'),
      $session-ids :=
        for $id in sessions:ids()
        where sessions:get($id,'username') eq $username-to-update
        return $id,
      $url := '/users/' || $username-to-update,
      $right := 'u:mgmt',
      $user-roles := u:roles-for-username($username-to-update),
      $context := map {'title': $title, 'lang': $lang, 'url':$url, 'return-url': ($return-url,'/converter/')[1]}
  return (
    ui:check($right, $lang, $url, $username-to-update),
    element html {
      config:get-html-head($context),
      element body {
        config:get-html-header($context),
        element div {
          attribute class {'well'},
          element h3 {i18n:val('sessions',$lang)},
          for $id in $session-ids
          return
            element div {
              attribute class {'well'},
              element details {
                element summary {$id},
                for $name in sessions:names($id)
                return
                  element div {
                    element span {$name || ':' || sessions:get($id, $name)}
                  },
                ui:create-anchor('Session löschen','/' || $lang || '/users/' || $username-to-update || '/sessions/' || $id || '/close?url=' || $url)
                }
            }
        },
        element div {
          attribute class {'well'},
          element h3 {i18n:val('roles',$lang)},
          for $role in u:roles()/role
          let $name := $role/xs:string(@name),
              $has-role := $user-roles = $name
          return element div {
                    element span {$name || ': '},
                  if ($has-role)
                  then ui:create-anchor(i18n:val('remove',$lang), '/' || $lang || '/users/' || $username-to-update || '/roles/remove/' || $name || '?url=' || $url)
                  else if (ui:check-only('u:mgmt')) then ui:create-anchor(i18n:val('add',$lang), '/' || $lang || '/users/' || $username-to-update || '/roles/add/' || $name || '?url=' || $url)
          }
        },
        element div {
          attribute class {'well'},
          element h3 {i18n:val('password',$lang)},
          element form {
            attribute method {'POST'},
            attribute action {'/' || $lang || '/users/' || $username-to-update || '/password/reset?url=' || $url},
            element div {
            element input {
              attribute class {'form-control'},
              attribute type {'password'},
              attribute name {'password'}
            }},
            element input {
              attribute class {'form-control'},
              attribute type {'submit'},
              attribute value {i18n:val('submit',$lang)}
            }
          }
        }
      }
    }
  )
};

declare
  %rest:GET
  %rest:path("/{$lang}/users")
  %output:method("html")
  %output:html-version('5')
function ui:user-management($lang){
  let $title := 'TranspectUI User Management',
      $url := '/users',
      $right := 'u:mgmt',
      $context := map {'title': $title, 'lang': $lang, 'url':$url, 'return-url': '/converter'}
  return
    (ui:check($right, $lang, $url),
    element html {
      config:get-html-head($context),
      element body {
        config:get-html-header($context),
        element div {
          attribute class {'well'},
          element h3 {i18n:val('user-preferences',$lang)},
          element div {
            for $user in u:users()/user
            return 
              element div {
                attribute class {'d-flex'},
                ui:create-anchor($user/username,'/' || $lang || '/users/' || $user/username),
                ui:create-anchor(i18n:val('delete',$lang),'/' || $lang || '/users/' || $user/username || '/delete?url=' || $url) 
              }
          }
        },
        element div {
          attribute class {'well'},
          element h3 {i18n:val('new-user',$lang)},
          element form {
            attribute method {'POST'},
            attribute action {'/' || $lang || '/users/new?url=' || $url},
            element form-group {
              attribute class {'form-group'},
              element label {
                attribute for {'username'},
                i18n:val('username',$lang)
              },
              element input {
                attribute class {'form-control line '},
                attribute type {'text'},
                attribute name {'username'}
              }
            },
            element form-group {
              attribute class {'form-group'},
              element label {
                attribute for {'password'},
                i18n:val('password',$lang)
              },
              element input {
                attribute class {'form-control line'},
                attribute type {'password'},
                attribute name {'password'}
              }
            },
            element form-group {
              element input {
                attribute class {'form-control line'},
                attribute type {'submit'},
                attribute value {i18n:val('submit',$lang)}
              }
            }
          }
        }
      }
    }
  )
};

declare
  %rest:GET
  %rest:path("/{$lang}/logout")
  %rest:query-param("url", "{$url}")
  %output:method("html")
  %output:html-version('5')
function ui:logout($lang, $url){
  session:close(),
  web:redirect($url)
};

declare %private function ui:create-anchor($text as xs:string? := (), $href as xs:string? := '#', $classes as xs:string* := (), $allowed as xs:boolean := true()){
  if ($allowed)
  then hf:create-anchor(config:url($href), $text, $classes)
  else
    element span {
      attribute class {string-join(($classes,'disallowed'),' ')},
      $text
    }
};


declare %private function ui:close-session($id) {
  sessions:close($id)
};