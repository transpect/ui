module namespace ui  = 'http://le-tex.de/transpectui';
import module namespace conv = 'http://le-tex.de/converter' at 'converter.xqm';
import module namespace config = 'http://le-tex.de/config' at 'config.xqm';
import module namespace hf = 'http://le-tex.de/helper-functions' at 'helper-functions.xqm';
import module namespace i18n = 'http://le-tex.de/i18n' at 'i18n.xqm';
import module namespace u = 'http://le-tex.de/user' at 'user.xqm';
import module namespace tr = 'http://le-tex.de/transpect' at 'transpect.xqm';
import module namespace ns = 'http://le-tex.de/namespaces' at '/opt/basex/webapp/transpectui/namespaces.xqm';

declare function ui:check($right as xs:string?, $lang as xs:string, $return-url as xs:string?, $owner as xs:string? := ()){
  let $is-logged-in := exists(ui:access-session('username')),
      $is-allowed := if (exists($right)) then ui:check-only($right, $owner) else true()
  return
    if ($is-logged-in)
    then if ($is-allowed)
         then ()
         else web:redirect(config:url( '/' ||$lang || '/' || 'error?url=' || '/' || $lang || $return-url || '&amp;message=' || i18n:val('not-allowed-message',$lang)))
    else web:redirect(config:url( '/' ||$lang || '/' || 'login?url=' || '/' || $lang || $return-url || '&amp;message=' || i18n:val('not-logged-in-message',$lang)))
};

declare function ui:check-only($right as xs:string?, $owner as xs:string? := ()){
  let $username := ui:access-session('username'),
      $token := ui:access-session('token'),
      $is-allowed := tr:check($username, $token, $right) or ($owner eq $username)(:,
      $log := hf:log('r: ' || $right || ' u: ' || ui:access-session('username') || ' o: ' || $owner || ' a: ' || $is-allowed,'CHECK'):)
  return $is-allowed
};

declare
  %rest:GET
  %rest:path("/")
  %output:method("html")
  %output:html-version('5')
function ui:default() {
  web:redirect(config:url('/de' ))
};

declare
  %rest:GET
  %rest:path("/{$lang}")
  %output:method("html")
  %output:html-version('5')
function ui:default($lang) {
  let $title := 'TranspectUI',
      $header := request:header-map(),
      $username := ui:access-session('username'),
      $converters as element(converter)* := tr:get-local-converter(),
      $workers as element(worker)* := tr:get-worker(),
      $url := '/',
      $context := map {'title': $title, 'lang': $lang, 'url':$url,'username':$username}
  return (
    ui:check((), $lang, $url),
    let $content := (
          element div {
            attribute class {'well'},
            element h2 {i18n:val('converters',$lang)},
            for $c in $converters
            let $allowed := ui:can-do($username,$url || 'converter/' || $c/@id)
            return ui:create-anchor($context, xs:string($c/@name),'/' || $lang || '/converter/' || $c/@id,(),$allowed)
          }[count($converters) gt 0 ],
          element div {
            attribute class {'well'},
            element h2 {i18n:val('workers',$lang)},
            for $w in $workers
            let $cs as element(converter)* := tr:get-worker-converter($w)
            return
              (
                element h3 {
                  attribute class {'ml-10'},
                  xs:string($w/@name)},
                for $c in $cs
                let $allowed := ui:can-do($username,'/worker/' || $c/@worker || '/converter/' || $c/@id)
                return ui:create-anchor($context, xs:string($c/@name),'/' || $lang || '/worker/' || $c/@worker || '/converter/' || $c/@id,'ml-20',$allowed)
              )
          }[count($workers) gt 0 ]),
        $description := 
          element div {
            attribute class {'well'},
            element h2 {'Startseite'},
            element ul {
            attribute class {'description'},
              element li {'Konverter'},
              element span {
                'Auflistung der lokal installierten Konverter.'
              },
              element li {'Worker'},
              element span {
                'Auflistung der auf anderen Workern installierter Konverter.'
              }
            }
          }
    return ui:page($context,$content,$description)

  )
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
      $converters as element(converter)* := (conv:get-all()),
      $url := '/converter',
      $context := map {'title': $title, 'lang': $lang, 'url':$url}
  return
    (
      ui:check($right, $lang, $url),
      let $content :=
            element div {
              attribute class {'well'},
              for $converter in ($converters)
              let $allowed := ui:check-only($converter/@worker || '-' || $converter/@id || ':convert')
              return ui:create-anchor($context, $converter/xs:string(@name), string-join(('', $lang, 'converter', $converter/xs:string(@id)),'/'), 'block', $allowed)
            },
          $description := ''
      return ui:page($context,$content,$description)
    )
};

declare
  %rest:GET
  %rest:path("/{$lang}/admin")
  %output:method("html")
  %output:html-version('5')
function ui:admin($lang as xs:string){
  let $right := 'admin:admin',
      $title := 'Admin View',
      $url := '/admin',
      $username := ui:access-session('username'),
      $header := request:header-map(),
      $memory as element(mem) := tr:system-memory(),
      $cpu as element(cpu) := tr:system-cpu(),
      $mem-bar-values := (
        map {'name': 'Inactive', 'value':xs:integer($memory/entry[@key eq 'Inactive']/@value), 'background-color':'lightblue'},
        map {'name': 'Active', 'value':xs:integer($memory/entry[@key eq 'Active']/@value), 'background-color':'lightblue'},
        map {'name': 'Free', 'value':xs:integer($memory/entry[@key eq 'MemFree']/@value), 'background-color':'beige'}
      ),
      $cpu-bar-values := (
        map {'name': 'Used', 'value':(100 - xs:decimal($cpu/cpuall/entry[@key eq '%idle']/@value)), 'background-color':'lightblue'},
        map {'name': 'Idle', 'value':xs:decimal($cpu/cpuall/entry[@key eq '%idle']/@value), 'background-color':'beige'}
      ),
      $context := map {'title': $title, 'lang': $lang, 'url':$url, 'username':$username}
  return (
    ui:check($right, $lang, $url),
    ui:page($context,
    (element div {
      attribute class {'well'},
      ui:stacked-bars($mem-bar-values, true()),
      element details {
        element summary {'Memory Details'},
        for $entry in $memory/entry
        let $value := if (matches(xs:string($entry/@value),'^\d+$')) then prof:human(xs:integer($entry/@value) * 1024) else xs:string($entry/@value)
        return 
          element div {
            attribute class {'d-flex start gap'},
            element div {xs:string($entry/@key)},
            element div {$value}
          }
        }
      },
    element div {
      attribute class {'well'},
      ui:stacked-bars($cpu-bar-values, false()),
      element details {
        element summary {'CPU Details'},
        for $k in $cpu/*
        return 
          element div {
            attribute class {'d-flex start gap'},
            element div {
              attribute style {'min-width:50px;'}, 
              name($k)},
            ui:stacked-bars(
            (
              for $entry in $k/entry[@key ne 'CPU'] where $entry/@key ne '%idle' return map {'name': $entry/@key, 'value':xs:decimal($entry/@value), 'background-color':'lightblue', 'color':'white'},
              for $entry in $k/entry[@key ne 'CPU'] where $entry/@key eq '%idle' return map {'name': $entry/@key, 'value':xs:decimal($entry/@value), 'background-color':'beige', 'color':'white'}
              
              ),
              false(),'small', false())
          }
        }
      }
    )))
};

(: WORKER :)

declare
  %rest:GET
  %rest:path("/{$lang}/worker")
  %output:method("html")
  %output:html-version('5')
function ui:worker-list($lang as xs:string){
  let $right := 'worker:list',
      $title := i18n:val('worker',$lang),
      $header := request:header-map(),
      $workers as element(worker)* := tr:get-worker(),
      $url := '/worker',
      $username := ui:access-session('username'),
      $right := tr:endpoint-right($url),
      $context := map {'title': $title, 'lang': $lang, 'url':$url, 'username':$username}
  return
    (
      ui:check($right, $lang, $url),
      let $content :=
            element div {
              attribute class {'well'},
              element h3 {i18n:val('workers',$lang)},
              for $worker in $workers
              let $status as element(*) := tr:get-worker-status($worker),
                  $status-text as xs:string := xs:string($status/@status),
                  $worker-cpu := $status/cpu,
                  $worker-memory := $status/memory,
                  $url := '/worker/' || $worker/@id,
                  $allowed := ui:can-do($username, $url)
              return
              element div {
                attribute class {''},
                ui:create-anchor($context, xs:string($worker/@name),'/' || $lang || $url, (),$allowed),
                element span {
                  attribute class {if ($status-text eq 'running') then 'green' else 'red'},
                  attribute title {i18n:val($status,$lang)},
                  ' ⬤'}
              }
            },
          $description := ''
      return ui:page($context,$content,$description)
    )
};

declare
  %rest:GET
  %rest:path("/{$lang}/worker/{$worker-id}")
  %output:method("html")
  %output:html-version('5')
function ui:worker-page($worker-id as xs:string, $lang as xs:string){
  let $worker := tr:get-worker($worker-id),
      $converters := tr:get-worker-converter($worker),
      $url := string-join(('','worker', $worker-id),'/'),
      $right := tr:endpoint-right($url),
      $title := i18n:val('worker',$lang) || ' ' || $worker-id,
      $username := ui:access-session('username'),
      $context := map {'right': $right, 'title': $title, 'lang': $lang, 'url':$url, 'username':$username}
  return (
    ui:check($right, $lang, $url),
    ui:page(
      $context,
      element div {
          attribute class {'well'},
          for $converter in ($converters)
          let $url := '/worker/' || $converter/@worker || '/converter/' || $converter/@id,
              $allowed := ui:can-do($username, $url)
          return
            ui:create-anchor($context, $converter/xs:string(@name) || (' (' || $converter/@worker || ')'), '/' || $lang || $url, 'block', $allowed)
        }
    )
  )
};

declare
  %rest:GET
  %rest:path("/{$lang}/worker/{$worker-id}/converter")
  %output:method("html")
  %output:html-version('5')
function ui:worker-converter-list($worker-id as xs:string, $lang as xs:string){
  let $worker as element(worker)? := tr:get-worker($worker-id),
      $converters as element(converter)* := tr:get-worker-converter($worker),
      $url := string-join(('','worker', $worker-id, 'converter'),'/'),
      $right := tr:endpoint-right($url),
      $title := i18n:val('converter', $lang) || ' (' || i18n:val('on-worker',$lang) || ' ' || $worker/@name ||  ')',
      $username := ui:access-session('username'),
      $context := map {'right': $right, 'title': $title, 'lang': $lang, 'url':$url}
  return (
    ui:check($right, $lang, $url),
    ui:page(
      $context,
      element div {
        attribute class {'well'},
        for $converter in ($converters)
        let $url := '/worker/' || $converter/@worker || '/converter/' || $converter/@id,
            $allowed := ui:can-do($username, $url)
        return
          ui:create-anchor($context, $converter/xs:string(@name) || (' (' || $converter/@worker || ')'), '/' || $lang || $url, 'block', $allowed)
      }
    )
  )
};

declare
  %rest:GET
  %rest:path("/{$lang}/worker/{$worker-id}/converter/{$converter-id}")
  %output:method("html")
  %output:html-version('5')
function ui:worker-converter-page($worker-id as xs:string, $converter-id as xs:string, $lang as xs:string){
  let $worker as element(worker)? := tr:get-worker($worker-id),
      $converter as element(converter)? := tr:get-worker-converter($worker, $converter-id),
      $url := string-join(('','worker', $worker-id, 'converter', $converter-id),'/'),
      $right := tr:endpoint-right($url),
      $username := ui:access-session('username'),
      $title := $converter/xs:string(@name) || ' (' || i18n:val('on-worker',$lang) || ' '  || $worker/@name ||  ')',
      $context := map {'right': $right, 'title': $title, 'lang': $lang, 'url':$url, 'username': $username}
  return if (exists($converter)) then ui:build-converter-page($converter, $context) else web:redirect(config:url('/' || $lang || '/converter'))
};

declare
  %rest:POST
  %rest:path("/{$lang}/worker/{$worker-id}/converter/{$converter-id}/convert")
  %rest:form-param('upload_file_uploaded_data', '{ $file }')
  %output:method("html")
  %output:html-version('5')
function ui:worker-converter-convert($worker-id as xs:string, $converter-id as xs:string, $file as map(xs:string, xs:base64Binary), $lang as xs:string){
  let $params := request:parameter-map(),
      $text-params := map:remove(request:parameter-map(),'upload_file_uploaded_data'),
      $worker as element(worker)? := tr:get-worker($worker-id),
      $converter as element(converter)? := tr:get-worker-converter($worker,$converter-id),
      $prev-runs as element(run)* := tr:get-runs($converter),
      $filename as xs:string := map:keys($file)[1],
      $count as xs:integer := count($prev-runs[filename eq $filename]),
      
      $log := hf:log('Convert file: ' || $filename || ' Delete: ' || xs:string($count),'CONVERT'),
      $max-prevs as xs:integer := (xs:integer($config:file/configurations/configuration/duplicate-files/@max),1)[1], 
      $delete-prev-runs :=
        if ($count ge $max-prevs)
        then 
          (for $run in $prev-runs
          order by $run/start
          where $run/status = ( 'stopped','canceled')
          return $run)[position() ge $max-prevs] ! tr:delete-run(., $converter, $worker)
        else (),
      $run as element(run)? := tr:start-run($file, $text-params, $converter, ui:access-session('username'), $worker)
  return if ($run/error or not(exists($run)))
         then web:redirect(config:url('/' || $lang || '/worker/' || $worker-id || '/converter/' || $converter-id || '/error/' || $run/error)) 
         else web:redirect(config:url('/' || $lang || '/worker/' || $worker-id || '/converter/' || $converter-id || '/runs/'  || $run/runid))
};

declare
  %rest:GET
  %rest:path("/{$lang}/worker/{$worker-id}/converter/{$converter-id}/runs")
  %output:method("html")
  %output:html-version('5')
function ui:get-worker-converter-runs($worker-id as xs:string, $converter-id as xs:string, $lang as xs:string){
  let $url := '/worker/' || $worker-id || '/converter/' || $converter-id || '/runs',
      $right := tr:endpoint-right($url),
      $check := ui:check($right,$lang,$url)
  return (
    $check,
    let $worker as element(worker)? := tr:get-worker($worker-id),
        $converter as element(converter)? := tr:get-worker-converter($worker,$converter-id),
        $username := ui:access-session('username'),
        $title := i18n:val('conversions',$lang),
        $return-url := '/worker/' || $worker-id || '/converter/' || $converter-id,
        $context := map {'title': $title, 'lang': $lang, 'url':$url, 'right':$right, 'username': $username}
    return ui:build-runs-page($converter, $context)
  )   
};

declare
  %rest:GET
  %rest:path("/{$lang}/worker/{$worker-id}/converter/{$converter-id}/runs/{$runid}")
  %output:method("html")
  %output:html-version('5')
function ui:worker-run-info($worker-id as xs:string, $converter-id as xs:string, $runid as xs:string, $lang as xs:string){
  let $url := string-join(('','worker', $worker-id, 'converter', $converter-id, 'runs', $runid),'/')
  return (
    ui:check('', $lang, $url),
    let $worker as element(worker)? := tr:get-worker($worker-id),
        $converter as element(converter)? := tr:get-worker-converter($worker,$converter-id),
        $run as element(run) := tr:get-run($runid, $converter,$worker),
        $title as xs:string? := $run/filename,
        $username := ui:access-session('username'),
        $context := map {'lang': $lang, 'title': $title, 'url': $url,'username':$username}
        
    return ui:build-run-page($converter, $run, $context, $worker)
    )
};

declare
  %rest:GET
  %ui:exclude
  %rest:query-param("url", "{$return-url}")
  %rest:path("/{$lang}/worker/{$worker-id}/converter/{$converter-id}/runs/{$runid}/cancel")
function ui:stop-worker-run-frontend($worker-id, $converter-id, $runid, $lang, $return-url){
  let $worker as element(worker)? := tr:get-worker($worker-id),
      $converter as element(converter)? := tr:get-worker-converter($worker,$converter-id),
      $run := tr:get-run($runid, $converter, $worker),
      $username := ui:access-session('username'),
      $is-allowed := ui:check-only($worker-id || $converter-id || ':admin',$run/username),
      $cancel := if ($is-allowed) then tr:stop-run($run, $username, $converter, $worker) else ()
  return web:redirect(config:url($return-url))
};

declare
  %rest:GET
  %rest:path("/{$lang}/worker/{$worker-id}/converter/{$converter-id}/runs/{$runid}/download/{$filename}")
function ui:worker-download($lang as xs:string, $worker-id as xs:string, $converter-id as xs:string, $runid as xs:string, $filename as xs:string) {
  let $format := $filename ! tokenize('.')[last()],
      $worker as element(worker)? := tr:get-worker($worker-id),
      $converter as element(converter)? := tr:get-worker-converter($worker,$converter-id),
      $run := tr:get-run($runid, $converter, $worker),
      $data := tr:get-file($run, $filename, $converter, $worker)
  return
      (web:response-header(
        map { 'media-type': 'application/' || $format},
        map { 'Content-Disposition': 'attachement;filename=' || $filename}),
       $data)
};

declare
  %rest:GET
  %ui:exclude
  %rest:path("/{$lang}/worker/{$worker-id}/converter/{$converter-id}/runs/{$runid}/show/{$filename}")
  %output:method("html")
  %output:html-version('5')
function ui:worker-show($lang, $worker-id, $converter-id, $runid, $filename) {
  if (ui:check-only(''))
  then
    let $extention := ($filename => tokenize('[\./]'))[last()],
        $show-direct as xs:boolean := $extention = ('xhtml','html'),
        $format := $filename ! tokenize('.')[last()],
        $worker as element(worker)? := tr:get-worker($worker-id),
        $converter as element(converter)? := tr:get-worker-converter($worker,$converter-id),
        $run as element(run)? := tr:get-run($runid, $converter, $worker),
        $data as document-node(element())* := parse-xml(tr:get-file($run, $filename,  $converter, $worker))
    return if ($show-direct) then $data else web:error('415','Das Dokument kann nicht angezeigt werden.')
  else web:error(403, 'You are not allowed to access this file.')
};

(: CONVERTER :)

declare
  %rest:GET
  %rest:path("/{$lang}/converter/{$converter-id}")
  %output:method("html")
  %output:html-version('5')
function ui:converter-page($converter-id as xs:string, $lang as xs:string){
  let $converter as element(converter)? := conv:get($converter-id),
      $url := '/converter/' || $converter-id,
      $right := tr:endpoint-right($url),
      $title := $converter/xs:string(@name),
      $username := ui:access-session('username'),
      $context := map {'right': $right, 'title': $title, 'lang': $lang, 'url':$url, 'username':$username}
  return if (exists($converter)) then ui:build-converter-page($converter, $context) else web:redirect(config:url('/' || $lang || '/converter'))
};

declare
  %rest:GET
  %rest:path("/{$lang}/converter/{$converter-id}/runs")
  %output:method("html")
  %output:html-version('5')
function ui:get-converter-runs($converter-id as xs:string, $lang as xs:string){
  let $converter as element(converter)? := tr:get-local-converter($converter-id),
      $runs := tr:get-runs($converter),
      $username := ui:access-session('username'),
      $converter as element(converter) := conv:get($converter-id),
      $title := i18n:val('conversions',$lang),
      $url := '/converter/' || $converter-id || '/runs',
      $return-url := '/converter/' || $converter-id,
      $right := tr:endpoint-right($url),
      $context := map {'title': $title, 'lang': $lang, 'url':'/converter/'|| $converter-id || '/runs', 'right':$right, 'username': $username}
  return ui:build-runs-page($converter, $context)
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
      $username := ui:access-session('username'),
      $run as element(run) := tr:start-run($file, $text-params, $converter, $username) 
  return if ($run/error)
         then web:redirect(config:url('/' || $lang ||'/converter/' || $converter-id || '/error/' || $run/error)) 
         else web:redirect(config:url('/' || $lang ||'/converter/' || $converter-id || '/runs/'   || $run/runid))
};

declare
  %rest:GET
  %rest:path("/{$lang}/converter/{$converter-id}/runs/{$runid}")
  %output:method("html")
  %output:html-version('5')
function ui:run-info($converter-id as xs:string, $runid as xs:string, $lang as xs:string){
  let $url := '/converter/' || $converter-id || '/runs/' || $runid
  return (
    ui:check('', $lang, $url),
    let $converter as element(converter) := conv:get($converter-id),
        $run as element(run)? := tr:get-run($runid),
        $title as xs:string? := $run/filename,
        $username := ui:access-session('username'),
        $context := map {'lang': $lang, 'title': $title, 'url': $url, 'username': $username}
        
    return ui:build-run-page($converter, $run, $context)
    )
};

declare
  %rest:GET
  %ui:exclude
  %rest:query-param("url", "{$return-url}")
  %rest:path("/{$lang}/converter/{$converter-id}/runs/{$runid}/cancel")
function ui:stop-run-frontend($runid, $lang, $converter-id, $return-url){
  let $run := tr:get-run($runid),
      $is-allowed := ui:check-only($converter-id || ':admin',$run/username),
      $cancel := if ($is-allowed) then tr:stop-run($run) else ()
  return web:redirect(config:url($return-url))
};

declare
  %rest:GET
  %rest:path("/{$lang}/converter/{$converter-id}/runs/{$runid}/download/{$filename}")
function ui:download($lang, $converter-id, $runid, $filename) {
  let $converter as element(converter)? := tr:get-local-converter($converter-id),
      $run as element(run)? := tr:get-run($runid, $converter),
      $outpath := $run?params[matches(.,'OUT_DIR')] ! tokenize(.,'=')[2],
      $format := $filename ! tokenize('.')[last()],
      $filepath := $outpath || $filename,
      $filesize := file:size($filepath),
      $data := tr:get-file($run, $converter, $filename)
  return
      (web:response-header(
        map { 'media-type': 'application/' || $format},
        map { 'Content-Disposition': 'attachement;filename=' || $filename,
              'Content-Length': $filesize }),
       $data)
};

declare
  %rest:GET
  %ui:exclude
  %rest:path("/{$lang}/converter/{$converter-id}/runs/{$runid}/show/{$filename}")
  %output:method("html")
  %output:html-version('5')
function ui:show($lang, $converter-id, $runid, $filename) {
  if (ui:check-only(''))
  then
    let $extention := ($filename => tokenize('[\./]'))[last()],
        $show-direct as xs:boolean := $extention = ('xhtml','html'),
        $format := $filename ! tokenize('.')[last()],
        
        $converter as element(converter)? := tr:get-local-converter($converter-id),
        $run as element(run)? := tr:get-run($runid, $converter),
        $data as document-node(element(*)) := parse-xml(tr:get-file($run, $filename,  $converter))
    return if ($show-direct) then $data else web:error('415','Das Dokument kann nicht angezeigt werden.')
  else web:error(403, 'You are not allowed to access this file.')
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
      $context := map {'title': $title, 'lang': $lang, 'url':$url, 'hide-login':true()}
  return
    ui:page(
      $context,
      (
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
            attribute action {'do-login?url=' || $return-url},
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
      )
    )
};

declare
  %rest:POST
  %rest:path("/{$lang}/do-login")
  %rest:form-param("url", "{$url}")
  %rest:form-param("username", "{$username}")
  %rest:form-param("password", "{$password}")
function ui:do-login($lang as xs:string, $url as xs:string?, $username as xs:string?, $password as xs:string?){
  let $is-valid as xs:boolean := u:validate-password($username, $password),
      $token as (element(token)|element(error)) :=
        if ($is-valid)
        then u:get-new-token($username)
        else element error {i18n:val('login-failed',$lang)},
      $is-error := $token/self::error
  return
    if ($is-error) 
    then web:redirect('error?url=' || 'login&amp;message=' || i18n:val('login-failed',$lang))
    else (
      ui:access-session('token', $token/self::token/text()),
      ui:access-session('timestamp', current-dateTime()),
      ui:access-session('username', $username),
      if ($url and $url ne '/login') then web:redirect($url) else web:redirect('/')
    )
};

declare
  %rest:GET
  %ui:exclude
  %rest:path("/{$lang}/error")
  %rest:query-param("url", "{$return-url}")
  %rest:query-param("message", "{$message}")
  %output:method("html")
  %output:html-version('5')
function ui:error-frontend($lang as xs:string, $return-url as xs:string?, $message as xs:string?){
  let $title := 'TranspectUI Error',
      $url := '/error',
      $context := map {'title': $title, 'lang': $lang, 'url':$url}
  return
    ui:page(
      $context,
      element div {
          attribute class {'well'},
          element div {
            attribute class {'red'},
            $message
          },
          element div {
            ui:create-anchor($context, i18n:val('back',$lang), $return-url)
          }
        }
    )
};

declare
  %rest:GET
  %rest:path("/{$lang}/users/{$username-to-update}/roles/{$role}/add")
  %rest:query-param("url","{$url}")
  %rest:query-param("return-url","{$return-url}")
  %output:method("html")
  %output:html-version('5')
function ui:user-add-role($lang as xs:string, $username-to-update as xs:string, $role as xs:string, $return-url as xs:string?, $url as xs:string?){
  let $right := 'u:mgmt',
      $can-do := ui:check-only($right, $lang),
      $log := if ($can-do) then hf:log('adding role ' || $role || ' to ' || $username-to-update || ' by ' || ui:access-session('username') || '(' || $can-do || ')','ROLES') else (),
      $do-update := if ($can-do) then u:add-role($username-to-update, $role) else ()
  return web:redirect(config:url('/' || $lang || $url  || ('?return-url=' || $return-url)[$return-url]))
};

declare
  %rest:GET
  %rest:path("/{$lang}/users/{$username-to-update}/roles/{$role}/remove")
  %rest:query-param("url","{$url}")
  %rest:query-param("return-url","{$return-url}")
  %output:method("html")
  %output:html-version('5')
function ui:user-remove-role($lang, $username-to-update, $role, $return-url, $url){
  let $right := 'u:mgmt',
      $can-do := ui:check-only($right, $username-to-update),
      $log := if ($can-do) then hf:log('removing role ' || $role || ' from ' || $username-to-update || ' by ' || ui:access-session('username') || '(' || $can-do || ')','ROLES') else (),
      $do-update := if ($can-do) then u:delete-role($username-to-update, $role) else ()
  return web:redirect(config:url('/' || $lang || $url  || ('?return-url=' || $return-url)[$return-url]))
};

declare
  %rest:POST
  %rest:path("/{$lang}/users/{$username-to-update}/password/reset")
  %rest:query-param("url","{$url}")
  %rest:query-param("return-url","{$return-url}")
  %rest:form-param("new-password","{$new-password}")
  %rest:form-param("old-password","{$old-password}")
  %output:method("html")
  %output:html-version('5')
function ui:user-reset-password($lang, $username-to-update, $old-password, $new-password, $url, $return-url){
  let $right := 'u:mgmt',
      $can-do := ui:check($right, $lang, $return-url, $username-to-update),
      $old-pw-correct := u:validate-password(ui:access-session('username'),$old-password),
      $do-update := if ($can-do and $old-pw-correct) then u:set-password($username-to-update, $new-password) else ()
  return web:redirect(config:url('/' || $lang ||$url  || ('?return-url=' || $return-url)[$return-url]))
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
  %rest:path("/{$lang}/users/{$username-to-update}")
  %rest:query-param("return-url","{$return-url}")
  %output:method("html")
  %output:html-version('5')
function ui:user($lang, $username-to-update, $return-url){
  let $title := i18n:val('user-preferences',$lang),
      $username := ui:access-session('username'),
      $session-ids :=
        for $id in sessions:ids()
        where sessions:get($id,'username') eq $username-to-update
        return $id,
      $url := '/users/' || $username-to-update,
      $right := tr:endpoint-right($url),
      $owner := tr:endpoint-owner($url),
      $user-roles := u:roles-for-username($username-to-update),
      $user := u:users($username-to-update),
      $context := map {'title': $title, 'lang': $lang, 'url':$url, 'username': $username, 'return-url':$return-url}
  return (
    ui:check($right, $lang, $url, $username-to-update),
    ui:page($context,(
      element div {
        attribute class {'well'},
        element h3 {i18n:val('sessions',$lang)},
        (element span {attribute class {'date spacious'},i18n:val('last-online',$lang) || ': ' || hf:format-dateTime(xs:dateTime($user/xs:string(@last-online)))})[$user/@last-online],
        for $id in $session-ids
        return
          element div {
            attribute class {'well'},
            element details {
              element summary {$id},
              for $name in sessions:names($id)
              return
                element div {
                  element span {$name || ': ' || sessions:get($id, $name)}
                },
              ui:create-anchor($context, 'Session löschen','/' || $lang || '/users/' || $username-to-update || '/sessions/' || $id || '/close?url=' || $url || ('&amp;return-url=' || $return-url)[$return-url])
              }
          }
      },
      element div {
        attribute class {'well'},
        element h3 {i18n:val('roles',$lang)},
        for $role in tr:roles()/role
        let $name := $role/xs:string(@name),
            $has-role := $user-roles = $name
        return
          element div {
            if ($has-role)
            then (
              element span{ attribute class {'date'},'[' || i18n:val('add',$lang) || ']'},
              ui:create-anchor($context, '[' || i18n:val('remove',$lang) || ']', '/' || $lang || '/users/' || $username-to-update || '/roles/' || $name || '/remove?url=' || $url || ('&amp;return-url=' || $return-url)[$return-url])
            )
            else
              if (ui:check-only('u:mgmt'))
              then (
                ui:create-anchor($context, '[' || i18n:val('add',$lang) || ']', '/' || $lang || '/users/' || $username-to-update || '/roles/' || $name || '/add?url=' || $url || ('&amp;return-url=' || $return-url)[$return-url]),
                element span{attribute class {'date'},'[' || i18n:val('remove',$lang) || ']'}
              ),
            element span {' - ' || $name},
            element span {attribute class {'date'}, ' (rights: ' || string-join(for $right in $role/right return ($right/@name,$right/@matches),', ') || ')'},
            if ($name eq 'admin') then ui:create-anchor($context, 'Admin View', '/' || $lang || '/admin', ('ml-10'), ui:can-do($context?username, '/' || $lang || '/admin')) else ()
          }
      },
      element div {
        attribute class {'well'},
        element h3 {i18n:val('password',$lang)},
        
        element form-group {
          attribute class {'form-group'},
          element form {
            attribute method {'POST'},
            attribute action {'/' || $lang || '/users/' || $username-to-update || '/password/reset?url=' || $url || ('&amp;return-url=' || $return-url)[$return-url]},
            attribute class {},
            element form-group {
              attribute class {'form-group'},
              element label {
                attribute for {'old-password'},
                i18n:val('old-password',$lang)
              },
              element input {
                attribute class {'form-control line'},
                attribute type {'password'},
                attribute name {'old-password'}
              }
            },
            element form-group {
              attribute class {'form-group'},
              element label {
                attribute for {'password'},
                i18n:val('new-password',$lang)
              },
              element input {
                attribute class {'form-control line'},
                attribute type {'password'},
                attribute name {'password'}
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
      }(:,
      element div {
        attribute class {'well'},
        element details {
          element summary {'All Links'},
          let $full := ui:build-full-map($username-to-update,$lang)
          return
            for $k in map:keys($full)
            let $val := $full?$k 
            return
              if (exists($val))
              then
                element details {
                  attribute class {'stacked'},
                  element summary {$k},
                  $val
                }
              else
                element span {attribute class {'d-block stacked'}, $k}
        }
      }:)
    ),())
  )
};

declare
  %rest:GET
  %rest:path("/{$lang}/users/{$username-to-update}/delete")
  %rest:query-param("url","{$return-url}")
  %output:method("html")
  %output:html-version('5')
function ui:user-new($lang,$username-to-update, $return-url){
  let $right := 'u:mgmt',
      $can-do := ui:check-only($right,$username-to-update),
      $do-update := if ($can-do) then u:delete-user($username-to-update) else (),
      $log := if ($can-do) then hf:log('delete user: ' ||$username-to-update)
  return web:redirect(config:url('/' || $lang ||$return-url))
};

declare
  %rest:GET
  %ui:exclude
  %rest:path("/{$lang}/users/{$username-to-update}/sessions/{$id}/close")
  %rest:query-param("url","{$return-url}")
  %output:method("html")
  %output:html-version('5')
function ui:user-cancel-session($lang,$username-to-update,$id,$return-url){
  let $right := 'u:mgmt',
      $can-do := ui:check($right, $lang, $return-url, $username-to-update),
      $do-update :=
        if (not(exists($can-do))) then ui:close-session($id) else (hf:log('not-allowed','SESSION-CLOSE'))
  return web:redirect(config:url('/' || $lang ||$return-url))
};

declare
  %rest:GET
  %rest:path("/{$lang}/users")
  %output:method("html")
  %output:html-version('5')
function ui:user-management($lang){
  let $title := 'TranspectUI User Management',
      $url := '/users',
      $right := tr:endpoint-right($url),
      $username := ui:access-session('username'),
      $context := map {'title': $title, 'lang': $lang, 'url':$url,'username':$username},
      $online-users as xs:string* := (job:execute($ns:data || 'data:get-online-users()'),$username)
  return (
    ui:check($right, $lang, $url),
    ui:page(
      $context,
      (
        element div {
          attribute class {'well'},
          element h3 {i18n:val('user-preferences',$lang)},
          element div {
            for $user in u:users()/user
            return 
              element div {
                attribute class {'d-flex'},
                element div {ui:create-anchor($context, $user/username,'/' || $lang || '/users/' || $user/username),
                if ($online-users = $user/username)
                then element span {attribute class {'green'},' ⬤'}
                else element span {attribute class {'red'},' ⬤'}},
                ui:create-anchor($context, i18n:val('delete',$lang),'/' || $lang || '/users/' || $user/username || '/delete?url=' || $url) 
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
      )
    )
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

declare %private function ui:create-anchor($context, $text as xs:string? := (), $href as xs:string? := '#', $classes as xs:string* := (), $allowed as xs:boolean := true()){
  let $right := tr:endpoint-right($href),
      $owner := tr:endpoint-owner($href),
      $roles-for-right := tr:roles-for-right($right),
      $title := 
        i18n:val('requires-right',$context?lang) ||
        ' ' ||
        $right ||
        ' ' || 
        i18n:val('in-role',$context?lang) ||
        ': ' ||
        string-join($roles-for-right,' ' ||
          i18n:val('or',$context?lang) || ' '
        )
  return
    if ($allowed)
    then hf:create-anchor(config:url($href), $text, $classes, $href)
    else
      element span {
        attribute class {string-join(($classes,'disallowed'),' ')},
        attribute data-href {config:url($href)},
        attribute title {$title},
        $text
      }
};

declare %private function ui:close-session($id) {
  let $log := hf:log($id, 'SESSION-CLOSE')
  return sessions:close($id)
};

declare %private function ui:access-session($name) {
  session:get($name),
  session:set('accessed',current-dateTime())
};

declare %private function ui:access-session($name,$value) {
  session:set($name,$value),
  session:set('accessed',current-dateTime())
};

declare function ui:empty-run-info($tag, $lang) {
  element div {
    attribute class {'run-info line date'},
    i18n:static-replacement($tag,$lang)
  }
};

declare function ui:build-runs-page($converter as element(converter), $context as map(xs:string, item()*)){
  ui:check($context?right, $context?lang, $context?return-url),
  let $runs as element(run)* := tr:get-runs($converter),
      $allowed-runs := 
        for $run in $runs
        where tr:allowed($converter, $context?username,$run)
        return $run,
      $running-runs :=
        for $run in $allowed-runs
        where xs:boolean($run/status/text() eq 'running')
        return $run,
      $finished-runs :=
        for $run in $allowed-runs
        where not(xs:boolean($run/status/text() = ('pending','running')))
        return $run,
      $pending-runs :=
        for $run in $allowed-runs
        where xs:boolean($run/status/text() eq 'pending')
        return $run,
      $context := map:merge(($context, map {'refresh': 5}))
  return
    ui:page(
      $context, 
      element div {
          attribute class {'well'},
          element div {
            attribute class {'date spacious'},
            i18n:val('called',$context?lang) || ': ' || hf:format-dateTime(current-dateTime())
          },
          element div {
            attribute class {'well'},
            i18n:val('pending-conversions',$context?lang) || ':',
            if (count($pending-runs) eq 0)
            then ui:empty-run-info('empty-pending',$context?lang)
            else
              for $run in $pending-runs
              order by xs:dateTime($run/start/text()) descending
              return ui:run-info-display($run, $converter, $context)
          },
          element div {
            attribute class {'well'},
            i18n:val('running-conversions',$context?lang) || ':',
            if (count($running-runs) eq 0)
            then ui:empty-run-info('empty-running',$context?lang)
            else
              for $run in $running-runs
              order by xs:dateTime($run/start/text()) descending
              return ui:run-info-display($run, $converter, map:put($context,'progress',true()))
          },
          element div {
            attribute class {'well'},
            i18n:val('finished-conversions',$context?lang) || ':',
            if (count($finished-runs) eq 0)
            then ui:empty-run-info('empty-finished',$context?lang)
            else
              for $run in $finished-runs
              order by xs:dateTime($run/start/text()) descending
              return ui:run-info-display($run, $converter, $context)
          }
        }
    )
};

declare function ui:run-info-display($run as element(run), $converter as element(converter), $context as map(*)){
  let $runid as xs:string := $run/runid,
      $filename:= $run/filename,
      $start as xs:dateTime := xs:dateTime($run/start),
      $status as xs:string? := $run/status/text(),
      $running-text := i18n:val($status,$context?lang),
      $username as xs:string? := $run/username,
      $worker as element(worker)? := tr:get-worker($converter/@worker),
      $is-worker as xs:boolean := exists($worker), 
      
      $logs as element(line)* :=
        if ($context?progress)
        then tr:get-file-logs($run, $converter, $worker)
        else (),
      $progress as xs:decimal := if (exists($converter/progress/@max)) then count($logs) div xs:integer($converter/progress/@max) else 0,
      $converter-url := 
        if ($is-worker)
        then '/' ||$context?lang || '/worker/' || $converter/@worker || '/converter/' || $converter/@id
        else '/' ||$context?lang || '/converter/' || $converter/@id
  return 
    element div {
      attribute class {'run-info line'},
      element div {
        attribute class {'run-info running'},
        $running-text || (' (' || format-number($progress,'1%') || ')')[xs:boolean($context?progress) and exists($converter/progress/@max)],
        hf:create-anchor(config:url($converter-url || '/runs/' || $runid), if ($status eq 'running') then i18n:static-replacement("logs",$context?lang) else i18n:static-replacement("results",$context?lang))
      },
      element div {
        attribute class {'run-info runid'},
        $runid
      },
      element div {
        attribute class {'run-info starttime'},
        hf:format-dateTime($start)
      },
      element div {
        attribute class {'run-info file'},
        $filename
      },
      element div {
        attribute class {'run-info username'},
        $username
      },
      element div {
        attribute class {'run-info username'},
        xs:string($worker/@id)
      }[$is-worker],
      element div {
        attribute class {'run-info cancel'},
        hf:create-anchor(config:url($converter-url || '/runs/' || $runid || '/cancel' || '?url=/' || $context?lang || $context?url), i18n:static-replacement("cancel",$context?lang))
      }[not($status = ('stopped','canceled'))]
    }
};

declare function ui:build-run-page($converter as element(converter), $run as element(run), $context as map(xs:string,item()*), $worker as element(worker)? := ()){
  ( ui:check('', $context?lang, $context?url),
    let $status as xs:string := $run/status,
        $is-running as xs:boolean := $status eq 'running' or $status eq 'pending',
        $parameters as xs:string* := $run/params/line,
        $runid as xs:string := $run/runid,
        $short-status := switch ($status)
                          case 'running' return '▶️'
                          case 'pending' return '⏳'
                          case 'stopped' return '✔️'
                          default return '-',
        $title as xs:string? := $run/filename,
        $is-allowed as xs:boolean := tr:allowed($converter, ui:access-session('username'),$run),
        $start as xs:dateTime := xs:dateTime($run/start),
        $end as xs:dateTime? := if (exists($run/end)) then xs:dateTime($run/end) else (),
        $subtitle as xs:string? := hf:format-dateTime(xs:dateTime($run/start)) || (" - " || hf:format-dateTime($end) || ' (' || hf:format-duration($end - $start) || ')')[exists($end)],
        $refresh := if ($is-running) then 5 else (),
        $context := map:merge(($context, map {'status': $short-status || ' ', 'refresh': $refresh, 'subtitle':$subtitle})),
        $log-dir := (($run/file => tokenize('/'))[position() ne last()] => string-join('/')) || '/debug/status',
        $logs as element(line)* := tr:get-file-logs($run, $converter, $worker),
        $job-results := tr:get-job-messages($run, $converter, $worker),
        $job-errors := tr:get-job-errors($run, $converter, $worker),
        (:$post-conv-actions := conv:get-post-conv-actions($converter),:)
        $result-files as element(file)*:= tr:get-result-files($run, $converter, $worker)
    return 
      ui:page(
        $context,
        element div {
            element div {
              attribute class {'well'},
              element h3 {i18n:val($status,$context?lang)},
              hf:create-anchor(config:url($runid || '/cancel' || '?url=/' || $context?lang || $context?url), i18n:val("cancel",$context?lang))[not($run/status = ('stopped','canceled'))]
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
              element summary {i18n:val('logs',$context?lang) || ' (' || count($logs) ||')'},
              for $log at $index in $logs
              return element div {
                attribute class {'log-entry'},
                element span {attribute class {'index'}, $index},
                element span {attribute class {'time'}, hf:format-dateTime($log/@time)},
                element span {$log/text()}
              }
            },
          element details {
            attribute class {'well'},
            if ($status eq 'stopped') then attribute open {} else (),
            element summary {i18n:val('results',$context?lang)},
            for $file in $result-files
            let $extention := ($file/@name => tokenize('[\./]'))[last()],
                $url := 
                    if (exists($converter/@worker))
                    then config:url('/' || $context?lang || '/worker/' || $converter/@worker || '/converter/' || $converter/@id || '/runs/' || $runid || '/download/' || $file/@name)
                    else config:url('/' || $context?lang || '/converter/' || $converter/@id || '/runs/' || $runid || '/download/' || $file/@name)
            return element div {
              attribute class {'line d-flex'},
              element div {
                attribute class {'filename'},
                element a {
                  attribute href {$url},
                  attribute target {'_blank'},
                  attribute download {$file/@name},
                  xs:string($file/@name)
                }}(:,
              element div {
                attribute class {'actions'},
                for $action in $post-conv-actions
                where matches($file/@name, $action/xs:string(@regex))
                return
                  element input{
                    attribute type {'button'},
                    attribute value {$action/xs:string(@message)},
                    attribute data-href {config:url(string-join(('/run',$runid, $file/@name, 'action', $action/xs:string(@target)),'/'))}
                  }
              }:)
            }
          },
          element details {
            attribute class {'well'},
            element summary {i18n:val('run',$context?lang)},
            element div {
              attribute class {'overflow'},
              for $m  at $index in $job-errors
              return element div {
                attribute class {'log-error'},
                element span {attribute class {'index'}, $index},
                element span {$m}
              },
              for $m  at $index in $job-results
              return element div {
                attribute class {'log-entry'},
                element span {attribute class {'index'}, $index},
                element span {$m}
              }
            }
          }
          }
      )
  )
};

declare function ui:build-converter-page($converter as element(converter), $context as map(xs:string, item()*)) {
  ui:check($context?right, $context?lang, $context?url),
  ui:page(
    $context,
    (
      element div {
        attribute class {'well'},
        attribute data-data {$context?username},
        attribute data-right {tr:endpoint-right($context?url || '/runs')},
        ui:create-anchor(
          $context, 
          i18n:val('prev-conversions',$context?lang),
          '/' || $context?lang || $context?url || '/runs',(),
          ui:can-do($context?username, $context?url || '/runs')
        )
      },
      element div {
        attribute class {'well'},
        element h2 {i18n:val('new-conversion',$context?lang)},
        element form {
          attribute action {config:url('/' || $context?lang || $context?url || '/convert')},
          attribute method {'POST'},
          attribute enctype {"multipart/form-data"},
          for $p in $converter/inputs/*
          return hf:parameter-to-html($p, $context?lang),
          element form-group{
            element label {
              i18n:val("upload",$context?lang)
            },
            element label {
              attribute class {'file-drop'},
              attribute id {'dropZone'},
              element input {
                attribute type {'file'},
                attribute id {'fileInput'},
                attribute name {'upload_file_uploaded_data'},
                element div {
                  attribute class {'file-content'},
                  element p {
                    attribute class {'file-title'},
                    i18n:val('dragDrop',$context?lang)
                  },
                  element p {
                    attribute class {'file-name'},
                    attribute id {'fileName'},
                    i18n:val('clickToChoose',$context?lang)
                  }
                }
              }
            },
            (:element input {
              attribute type {'text'},
              attribute required {''},
              attribute readonly {''},
              attribute name {'file-name'},
              attribute id {'file-name'},
              attribute class {'form-control invalid'},
              attribute onclick {"document.querySelector('#upload_file_uploaded_data').click();document.querySelector('#submit-to-conversion').classList.remove('disabled');"},
              attribute placeholder {i18n:val("select-file",$context?lang)},
              attribute autocomplete {'off'}
            },
            element input {
              attribute type {'file'},
              attribute id {'upload_file_uploaded_data'},
              attribute name {'upload_file_uploaded_data'},
              attribute class {'hidden'}
            },:)
            element button {
              attribute id {'submit-to-conversion'},
              attribute disabled {},
              attribute class {'primary-btn disabled'},
              attribute type {'submit'},
              i18n:val("submit-file",$context?lang)
            }
          }
        }
      }
    )
  )
};

declare %private function ui:page($context,$content,$description := ()){
  element html {
    ui:get-html-head($context),
    element body {
      ui:get-html-header($context),
      element div {
        attribute class {'d-flex'},
        element div {
          attribute class {'half'},
          $content
        },
        element div {
          attribute class {'half'},
          $description
        }[exists($description)]
      }
    }
  }
};

declare %private function ui:get-html-head($context) {
  element head {
    element meta{
      attribute http-equiv {'refresh'},
      attribute content {$context?refresh}
    }[$context?refresh gt 0],
    element title {
      $context?status || $context?title
    },
    element link {
      attribute rel {"stylesheet"},
      attribute type {"text/css"},
      attribute href {config:url("/static/transpectui.css")}
    },
    element link{
      attribute rel {"icon"},
      attribute type {"image/x-icon"},
      attribute href {config:url("/static/favicon-96x96.png")}
    },
    element script {
      attribute src {config:url("/static/transpectui.js")}
    }
  }
}; 

declare %private function ui:get-html-header($context as map(xs:string, item()?)) {
  element header {
    attribute class {'d-flex column'},
    element div {
    attribute class {'d-flex'},
      element a {
        attribute href {config:url('/' || $context?lang)},
        element img {
          attribute class {"header"},
          attribute src {config:url("/static/transpect.png")},
          attribute title {i18n:val('start',$context?lang)}
        }
      },
      element div {
        attribute class {'d-flex column center'},
        element h1 {attribute style {'margin-bottom: 0;'},$context?title},
        if ($context?subtitle) then element span {attribute class {'date'}, $context?subtitle}
      },
      element div {
        attribute class {'d-flex center gap'},
          element ul {
            for $language in $i18n:languages//language
            return (
              element a {
                attribute href {config:url("/" || $language/xs:string(@short) || $context?url)},
                element img {
                  attribute class {'lang-img'},
                  attribute src {config:url('/static/' || $language/xs:string(@short) ||'.png')}
                }
              }
            )
          },
          if (session:get('username'))
          then 
            element div {
              attribute class {'d-flex column'},
              attribute style {'margin-top: -5px;'},
              hf:create-anchor(config:url('/' || $context?lang || '/users/'|| session:get('username') || '?return-url=' || config:url($context?url)),session:get('username'),'lang-img right username'),
              hf:create-anchor(config:url('/' || $context?lang || '/logout?url=' || config:url('/' || $context?lang || $context?url)),i18n:static-replacement('logout', $context?lang),'lang-img')
            }
          else if (not($context?hide-login)) then hf:create-anchor(config:url('/' || $context?lang || '/login?url=' || config:url('/' || $context?lang || $context?url)),i18n:static-replacement('login', $context?lang),'lang-img')
      }
    },
    element div {
      attribute class {'d-flex start'},
      element div {
        attribute class {'nav'},
        element span {'Navigation: '},
        let $href := '',
            $allowed := ui:can-do($context?username, $href),
            $log := hf:log($context?username || '| ' || $href)
        return element span {ui:create-anchor($context, i18n:val('start',$context?lang), '/' || $context?lang || $href,(),$allowed)},
        if (exists($context?return-url))
        then (
          element span {', '},
          element span {ui:create-anchor($context, i18n:val('back',$context?lang), '/' || $context?lang || $context?return-url,(),true())})
      }[exists($context?username)],
      let $bc := ($context?url => tokenize('/'))[normalize-space(.)]
      return if ((count($bc) gt 1) and ($context?url ne '/login'))
      then (
        element span { attribute class {'desktop-only'}, '|'},
        element div {
          attribute class {'breadcrumbs'},
          let $parts := ($context?url => tokenize('/'))[position() ne last()]
          return 
            for $part at $i in $parts[normalize-space(.)](:[position() ne last()]:)
            let $href := string-join($parts[position() le $i + 1],'/'),
                $allowed := ui:can-do($context?username, $href),
                $log := hf:log($context?username || '| ' || $href)
            return element span {ui:create-anchor($context, $part, '/' || $context?lang || $href,(),$allowed)}
        }
        )
      else ()
    }
  }
}; 

declare function ui:can-do($username,$url as xs:string) {
  let $can := tr:can-do($username,tr:endpoint-right($url), tr:endpoint-owner($url)),
      $log := hf:log('u: ' || $url || ' u: ' || $username || ' c: ' || xs:string($can),'CAN')
  return $can
};

declare function ui:build-full-map($username as xs:string, $lang as xs:string) as map(*){
  let $worker-converter := tr:get-worker-converter(),  
      $user := u:users($username),
      $get-paths := inspect:module($ns:ui ! replace(.,".* at '|';",''))/*[annotation[@name eq 'rest:GET']][not(annotation[@name eq 'ui:exclude'])]/annotation[@name eq 'rest:path']/literal/text(),
      $roles := ($tr:dynamic-roles,u:roles()/role),
      $worker-paths := $get-paths[matches(.,'\$worker-id')],
      $non-worker-paths := $get-paths[not(matches(.,'\$worker-id'))][matches(.,'\$converter-id')],
      $username-paths := $get-paths[not(matches(.,'\$worker-id|\$converter-id'))][matches(.,'\$username-to-update')],
      $rest := $get-paths[not(matches(.,'\$worker-id|\$converter-id|\$username-to-update'))],
      $rest-map := map {'lang':$lang},
      $rest-merged := 
        for $url in $rest
        return
          let $n-url := hf:static-replace-variables($url,$rest-map,"") ! replace(.,'\{|\}',''),
              $right := tr:endpoint-right($n-url),
              $allowed as xs:boolean := (($user/roles/role/xs:string(@name) = tr:roles-for-right($right)) or not(exists($right)))
          order by $n-url
          where $allowed
          return hf:static-replace-variables($n-url,$rest-map),
      $username-maps := 
        for $u in u:users()/user
        return
          for $r in $roles/xs:string(@name)
          return
            map {'username-to-update':$u/username/text(),
                 'role':$r,
                 'lang':$lang},
      $username-merged := 
        for $url in $username-paths
        return
          for $m in $username-maps
          let $n-url := hf:static-replace-variables($url,$m,"") ! replace(.,'\{|\}',''),
              $right := tr:endpoint-right($n-url),
              $owner := tr:endpoint-owner($n-url),
              $allowed as xs:boolean := (($user/roles/role/xs:string(@name) = tr:roles-for-right($right)) or not(exists($right))) or $owner eq $username
          order by $n-url
          where $allowed
          return hf:static-replace-variables($n-url,$m),
      $non-worker-maps := 
        for $c in conv:get-all()
        let $runs := tr:get-runs($c)
        return
          for $r in $runs
          let $files as xs:string* := tr:get-result-files($r,$c)/@name
          return
            for $f in $files
            return
              map {
                'runid':$r/runid/text(),
                'converter-id':xs:string($c/@id),
                'allowed':tr:allowed($c, $username,$r),
                'filename': $f,
                'lang':$lang
              },
      $non-worker-merged := 
        for $url in $non-worker-paths
        return
          for $m in $non-worker-maps
          let $n-url := hf:static-replace-variables($url,$m,"") ! replace(.,'\{|\}',''),
              $right := tr:endpoint-right($n-url),
              $allowed as xs:boolean := (($user/roles/role/xs:string(@name) = tr:roles-for-right($right)) or not(exists($right))) and $m?allowed
          order by $n-url
          where $allowed
          return hf:static-replace-variables($n-url,$m),
      $worker-maps :=
        for $c in $worker-converter
        let $w := tr:get-worker($c/@worker),
            $runs := tr:get-runs($c)
        return
          for $r in $runs
          let $files as xs:string*:= tr:get-result-files($r,$c,$w)/@name
          return
            for $f in $files
            return 
              map {
                'worker-id':xs:string($c/@worker),
                'converter-id':xs:string($c/@id),
                'runid':$r/runid/text(),
                'allowed':tr:allowed($c,$username,$r),
                'filename':$f,
                'lang':$lang
              },
      $worker-merged := 
        for $url in $worker-paths
        return
          for $m in $worker-maps
          let $n-url := hf:static-replace-variables($url,$m,"") ! replace(.,'\{|\}',''),
              $right := tr:endpoint-right($n-url),
              $allowed as xs:boolean := (($user/roles/role/xs:string(@name) = tr:roles-for-right($right)) or not(exists($right))) and $m?allowed
          order by $n-url
          where $allowed
          return hf:static-replace-variables($n-url,$m)
  return 
    map {
      'default': ui:list-to-xml(distinct-values($rest-merged)),
      'user': ui:list-to-xml(distinct-values($username-merged)),
      'worker': ui:list-to-xml(distinct-values($worker-merged)),
      'local': ui:list-to-xml(distinct-values($non-worker-merged))
    }
};

declare function ui:list-to-xml($urls) {
  let $subs :=
        distinct-values(
          for $url in $urls
          let $tokens := tokenize($url,'/'),
              $subs := for $l in (1 to count($tokens)) return string-join($tokens[1 to $l],'/')
          return $subs
        )
  return ui:list-to-xml('',$subs,$urls)
};

declare function ui:list-to-xml($current, $subs, $urls){
  let $children := $subs[matches(.,'^' || $current || '/[^/]+$')],
      $url-children := $children[. = $urls]
  return
    if (((count($url-children) gt 0) or ($current = $urls)) and normalize-space($current) ne '')
    then 
      if ($current = $urls) then 
        if (count($children) gt 0)
        then
          element details {
            attribute class {'stacked'},
            element summary {
              element a {attribute href {$current},config:url($current)}
            },
            for $c in $children
            return ui:list-to-xml($c,$subs,$urls)
          }
        else
          element a {attribute class {'stacked d-block'}, attribute href {$current},config:url($current)}
      else
        element details {
          attribute class {'stacked'},
          attribute open {},
          element summary {tokenize($current,'/')[last()]},
          for $c in $children
          return ui:list-to-xml($c,$subs,$urls)
        }
    else for $c in $children
      return ui:list-to-xml($c,$subs,$urls)
};

declare function ui:stacked-bars($vals as map(*)*, $mem as xs:boolean, $class as xs:string? := (), $show-values as xs:boolean? := true()) {
  element div {
    attribute class {'bar-diagram d-flex start ' || $class},
    let $all as xs:integer := sum($vals ! .?value),
        $length as xs:decimal := xs:decimal(max(($vals ! .?value)))
    return (
      for $v in $vals
      let $name :=  $v?name,
          $value := $v?value,
          $display :=
            if (exists($value))
            then (if ($mem) then prof:human($value * 1024) else xs:integer(round($value)) || '%') ||' (' || $name || ')'
            else 'EMPTY'
      return
        element div {
          attribute class {'bar-content'},
          attribute style {'width:' || xs:string(($value div $length) * 100) || '%;' || (for $c in map:keys($v)[not(. = ('name','value'))] return $c || ': ' || $v?$c ||';')},
          attribute title {$display},
          $display[$show-values]
        })
  }
};