module namespace ui  = 'http://le-tex.de/transpectui';
import module namespace conv = 'http://le-tex.de/converter';
import module namespace config = 'http://le-tex.de/config';
import module namespace hf = 'http://le-tex.de/helper-functions';
import module namespace i18n = 'http://le-tex.de/i18n';
import module namespace u = 'http://le-tex.de/user';
import module namespace tr = 'http://le-tex.de/transpect';
import module namespace ns = 'http://le-tex.de/namespaces';

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
        ui:page-intro($context,
          i18n:val('converters',$lang),
          'Prüfen und konvertieren Sie Ihre Dokumente mit den verfügbaren Produktionspipelines.'),
        element section {
          attribute class {'tx-section'},
          element div {
            attribute class {'tx-section-heading'},
            element h2 {i18n:val('converters',$lang)}
          },
          for $c in $converters
          let $allowed := ui:can-do($username,'/converter/' || $c/@id),
              $runs as element(run)* := tr:get-runs($c),
              $running := count($runs[status = ('pending','running')]),
              $finished := count($runs[not(status = ('pending','running'))]),
              $desc := $c/xs:string(@description),
              $card := element span {
                attribute class {'tx-converter-icon'},
                ui:icon('shield', 24)
              }
          return
            if ($allowed)
            then element a {
              attribute class {'tx-converter-card'},
              attribute href {config:url('/' || $lang || '/converter/' || $c/@id)},
              $card,
              element span {
                attribute class {'tx-converter-card__body'},
                element span {
                  attribute class {'tx-card-title-row'},
                  element h3 {xs:string($c/@name)},
                  ui:icon('chevron-right', 19)
                },
                element p {if (normalize-space($desc)) then $desc else ()},
                element span {
                  attribute class {'tx-inline-stats'},
                  (element span {attribute class {'tx-dot tx-dot--info'}, xs:string($running) || ' ' || i18n:val('running-single',$context?lang)})[$running eq 1],
                  (element span {attribute class {'tx-dot tx-dot--info'}, xs:string($running) || ' ' || i18n:val('running-multi',$context?lang)})[$running gt 1],
                  element span {ui:icon('check', 14), xs:string($finished) || ' abgeschlossen'}
                }
              }
            }
            else element div {
              attribute class {'tx-converter-card'},
              attribute title {i18n:val('requires-right',$lang)},
              $card,
              element span {
                attribute class {'tx-converter-card__body'},
                element span {
                  attribute class {'tx-card-title-row'},
                  element h3 {xs:string($c/@name)}
                },
                element p {if (normalize-space($desc)) then $desc else ()}
              }
            }
        }[count($converters) gt 0],
        element section {
          attribute class {'tx-section'},
          element div {
            attribute class {'tx-section-heading'},
            element h2 {i18n:val('worker',$lang)}
          },
          element div {
            attribute class {'tx-worker-grid'},
            for $w in $workers
            let $status as element(*) := tr:get-worker-status($w),
                $status-text as xs:string := xs:string($status/@status),
                $wurl := '/worker/' || $w/@id,
                $allowed := ui:can-do($username, $wurl),
                $wconverters := tr:get-worker-converter($w)
            return
              element div {
                attribute class {'tx-worker-card'},
                element div {
                  element strong {xs:string($w/@name)},
                  element span {attribute class {'tx-mono'}, xs:string($w/@id)}
                },
                ui:status-badge($status-text, $lang, if ($status-text eq 'running') then 'Online' else 'Offline'),
                for $wc in $wconverters
                let $allowed := ui:can-do($username, $wurl || '/converter/' || $wc/@id),
                    $runs as element(run)* := tr:get-runs($wc),
                    $running := count($runs[status = ('running')]),
                    $pending := count($runs[status = ('pending')]),
                    $finished := count($runs[not(status = ('pending','running'))]),
                    $desc := $wc/xs:string(@description),
                    $card := element span {
                      attribute class {'tx-converter-icon'},
                      ui:icon('shield', 24)
                    }
                return
                  if ($allowed)
                  then element a {
                    attribute class {'tx-converter-card'},
                    attribute href {config:url('/' || $lang || $wurl ||  '/converter/' || $wc/@id)},
                    element span {
                      attribute class {'tx-converter-card__body'},
                      element span {
                        attribute class {'tx-card-title-row'},
                        element h3 {xs:string($wc/@name)},
                        ui:icon('chevron-right', 19)
                      },
                      element div {
                        attribute class {'tx-inline-stats'},
                        (element div {xs:string($running) || ' ' || i18n:val('running-single',$context?lang)})[$running eq 1],
                        (element div {xs:string($running) || ' ' || i18n:val('running-multi',$context?lang)})[$running gt 1],
                        (element div {xs:string($pending) || ' in der Warteschlange'})[$pending gt 0]
                      }
                    }
                  }
                  else element div {
                    attribute class {'tx-converter-card'},
                    attribute title {i18n:val('requires-right',$lang)},
                    element span {
                      attribute class {'tx-converter-card__body'},
                      element span {
                        attribute class {'tx-card-title-row'},
                        element h3 {xs:string($wc/@name)}
                      },
                      element p {if (normalize-space($desc)) then $desc else ()}
                    }
                  }
              }[count($wconverters) gt 0]
            }
        }[count($workers) gt 0])
    return ui:page($context,$content)

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
            attribute class {'tx-panel'},
            element div {
              attribute class {'tx-panel__header'},
              element h2 {i18n:val('converters',$lang)}
            },
            for $converter in ($converters)
            let $allowed := ui:check-only($converter/@worker || '-' || $converter/@id || ':convert')
            return ui:create-anchor($context, $converter/xs:string(@name), string-join(('', $lang, 'converter', $converter/xs:string(@id)),'/'), 'tx-text-btn d-block', $allowed)
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
      $title := 'Admin',
      $url := '/admin',
      $username := ui:access-session('username'),
      $header := request:header-map(),
      $memory as element(mem)? := try { tr:system-memory() } catch * { () },
      $cpu as element(cpu)? := try { tr:system-cpu() } catch * { () },
      $metrics-available as xs:boolean := exists($memory) and exists($cpu),
      $mem-values := (
        map {'name': 'Aktiv', 'value': xs:integer($memory/entry[@key eq 'Active']/@value)},
        map {'name': 'Inaktiv', 'value': xs:integer($memory/entry[@key eq 'Inactive']/@value)},
        map {'name': 'Frei', 'value': xs:integer($memory/entry[@key eq 'MemFree']/@value)}
      )[$metrics-available],
      $mem-total := sum($mem-values ! .?value),
      $mem-used := sum(($mem-values[?name ne 'Free']) ! .?value),
      $cpu-used := (100 - xs:decimal($cpu/cpuall/entry[@key eq '%idle']/@value))[$metrics-available],
      $cpu-values := (
        map {'name': 'Belegt', 'value': $cpu-used},
        map {'name': 'Leerlauf', 'value': xs:decimal($cpu/cpuall/entry[@key eq '%idle']/@value)}
      )[$metrics-available],
      $context := map {'title': $title, 'lang': $lang, 'url':$url, 'username':$username}
  return (
    ui:check($right, $lang, $url),
    ui:page($context,
      (
        ui:page-intro($context, $title, 'Systemstatus und Worker-Auslastung'),
        element div {
          attribute class {'tx-panel'},
          element p {
            attribute class {'tx-muted'},
            'Systemmetriken (Arbeitsspeicher, CPU) sind nur auf Linux-Workern verfügbar.'
          }
        }[not($metrics-available)],
        element div {
          attribute class {'tx-metrics-grid'},
          element div {
            attribute class {'tx-panel tx-metric'},
            element div {
              attribute class {'tx-panel__header'},
              element h2 {ui:icon('clock', 17), element span {'Arbeitsspeicher'}},
              element strong {prof:human($mem-used * 1024) || ' / ' || prof:human($mem-total * 1024)}
            },
            ui:stacked-bars($mem-values, true()),
            element div {
              attribute class {'tx-legend'},
              for $v at $i in $mem-values
              return element span {element i {attribute class {'tx-segment--' || ($i - 1)}}, $v?name}
            },
            element details {
              element summary {'Details'},
              element dl {
                attribute class {'tx-definition-list'},
                for $entry in $memory/entry
                let $value := if (matches(xs:string($entry/@value),'^\d+$')) then prof:human(xs:integer($entry/@value) * 1024) else xs:string($entry/@value)
                return (element dt {xs:string($entry/@key)},
                        element dd {$value})
              }
            }
          },
          element div {
            attribute class {'tx-panel tx-metric'},
            element div {
              attribute class {'tx-panel__header'},
              element h2 {ui:icon('refresh', 17), element span {'CPU'}},
              element strong {xs:string(round($cpu-used)) || ' % belegt'}
            },
            ui:stacked-bars($cpu-values, false()),
            element div {
              attribute class {'tx-legend'},
              for $v at $i in $cpu-values
              return element span {element i {attribute class {'tx-segment--' || ($i - 1)}}, $v?name}
            },
            element details {
              element summary {'Details'},
              element dl {
                attribute class {'tx-definition-list'},
                for $k in $cpu/cpuall/entry
                return (element dt {xs:string($k/@key)},
                        element dd {xs:string($k/@value)})
              }
            }
          }
        }[$metrics-available],
        element div {
          attribute class {'tx-panel'},
          element div {
            attribute class {'tx-panel__header'},
            element h2 {i18n:val('workers',$lang)},
            ui:status-badge('running', $lang, xs:string(count($config:file//controller/worker)) || ' konfiguriert')
          },
          element div {
            attribute class {'tx-admin-workers'},
            for $worker in $config:file//controller/worker
            let $status as element(*) := tr:get-worker-status($worker),
                $status-text as xs:string := xs:string($status/@status)
            return
              element div {
                element strong {xs:string($worker/@name)},
                element span {attribute class {'tx-mono'}, xs:string($worker/base-url)},
                ui:status-badge($status-text, $lang, if ($status-text eq 'running') then i18n:val('online',$lang) else i18n:val('offline',$lang))
              }
          }
        }[count($config:file//controller/worker) gt 0]
      )
    )
  )
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
      $right := tr:endpoint-right($url)[1],
      $context := map {'title': $title, 'lang': $lang, 'url':$url, 'username':$username}
  return
    (
      ui:check($right, $lang, $url),
      let $content :=
            element div {
              attribute class {'tx-panel'},
              element div {
                attribute class {'tx-panel__header'},
                element h2 {i18n:val('workers',$lang)}
              },
              element div {
                attribute class {'tx-worker-grid'},
                for $worker in $workers
                let $status as element(*) := tr:get-worker-status($worker),
                    $status-text as xs:string := xs:string($status/@status),
                    $url := '/worker/' || $worker/@id,
                    $allowed := ui:can-do($username, $url)
                return
                  element div {
                    attribute class {'tx-worker-card'},
                    element div {
                      element strong {xs:string($worker/@name)},
                      element span {attribute class {'tx-mono'}, xs:string($worker/@id)}
                    },
                    if ($allowed)
                    then element a {
                      attribute class {'tx-status tx-status--' || (if ($status-text eq 'running') then 'success' else 'neutral')},
                      attribute href {config:url('/' || $lang || $url)},
                      element span {attribute class {'tx-status__dot'}},
                      if ($status-text eq 'running') then i18n:val('online',$lang) else i18n:val('offline',$lang)
                    }
                    else ui:status-badge($status-text, $lang, if ($status-text eq 'running') then i18n:val('online',$lang) else i18n:val('offline',$lang))
                  }
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
      $right := tr:endpoint-right($url)[1],
      $title := i18n:val('worker',$lang) || ' ' || $worker-id,
      $username := ui:access-session('username'),
      $context := map {'right': $right, 'title': $title, 'lang': $lang, 'url':$url, 'username':$username}
  return (
    ui:check($right, $lang, $url),
    ui:page(
      $context,
      element div {
          attribute class {'tx-panel'},
          element div {
            attribute class {'tx-panel__header'},
            element h2 {xs:string($worker/@name)}
          },
          for $converter in ($converters)
          let $url := '/worker/' || $converter/@worker || '/converter/' || $converter/@id,
              $allowed := ui:can-do($username, $url)
          return
            ui:create-anchor($context, $converter/xs:string(@name) || (' (' || $converter/@worker || ')'), '/' || $lang || $url, 'tx-text-btn d-block', $allowed)
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
      $right := tr:endpoint-right($url)[1],
      $title := i18n:val('converter', $lang) || ' (' || i18n:val('on-worker',$lang) || ' ' || $worker/@name ||  ')',
      $username := ui:access-session('username'),
      $context := map {'right': $right, 'title': $title, 'lang': $lang, 'url':$url}
  return (
    ui:check($right, $lang, $url),
    ui:page(
      $context,
      element div {
        attribute class {'tx-panel'},
        for $converter in ($converters)
        let $url := '/worker/' || $converter/@worker || '/converter/' || $converter/@id,
            $allowed := ui:can-do($username, $url)
        return
          ui:create-anchor($context, $converter/xs:string(@name) || (' (' || $converter/@worker || ')'), '/' || $lang || $url, 'tx-text-btn d-block', $allowed)
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
      $right := tr:endpoint-right($url)[1],
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
      $filename as xs:string := map:keys($file)[1],
      $prev-runs as element(run)* := tr:get-runs($converter)[filename/text() eq $filename],
      $count as xs:integer := count($prev-runs),
      
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
      $right := tr:endpoint-right($url)[1],
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
      $right := tr:endpoint-right($url)[1],
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
      $right := tr:endpoint-right($url)[1],
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
      element div {
        attribute class {'tx-auth-card'},
        element div {
          attribute class {'tx-logo'},
          element span {'trans'},
          element b {'pect'}
        },
        element div {
          attribute class {'tx-auth-heading'},
          element h1 {i18n:val('login',$lang)},
          element p {'Willkommen bei transpectUI'}
        },
        element div {
          attribute class {'tx-alert tx-alert--danger'},
          ui:icon('alert', 17),
          element span {$message}
        }[$message],
        element form {
          attribute action {'do-login?url=' || $return-url},
          attribute method {'POST'},
          element label {
            i18n:val('username',$lang),
            element input {
              attribute type {'text'},
              attribute name {'username'},
              attribute autocomplete {'username'},
              attribute required {''},
              attribute autofocus {''}
            }
          },
          element label {
            i18n:val('password',$lang),
            element input {
              attribute type {'password'},
              attribute name {'password'},
              attribute autocomplete {'current-password'},
              attribute required {''}
            }
          },
          element input {
            attribute type {'hidden'},
            attribute name {'url'},
            attribute value {$return-url}
          },
          element button {
            attribute class {'tx-btn tx-btn--primary tx-btn--full'},
            attribute type {'submit'},
            element span {i18n:val('login',$lang)},
            ui:icon('arrow-right', 17)
          }
        },
        element p {
          attribute class {'tx-auth-note'},
          ui:icon('info', 15),
          element span {'Zugang über die Geschäftsstelle'}
        }
      }
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
      $context := map {'title': $title, 'lang': $lang, 'url':$url, 'center':true()}
  return
    ui:page(
      $context,
      element div {
        attribute class {'tx-error-card'},
        element div {
          attribute class {'tx-error-icon'},
          ui:icon('alert', 28)
        },
        element h1 {i18n:val('error',$lang)},
        element p {element span {$message}},
        element a {
          attribute class {'tx-btn tx-btn--secondary'},
          attribute href {config:url($return-url)},
          i18n:val('back',$lang)
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
      $right := tr:endpoint-right($url)[1],
      $owner := tr:endpoint-owner($url),
      $user-roles := u:roles-for-username($username-to-update),
      $user := u:users($username-to-update),
      $context := map {'title': $title, 'lang': $lang, 'url':$url, 'username': $username, 'return-url':$return-url}
  return (
    ui:check($right, $lang, $url, $username-to-update),
    ui:page($context,(
      ui:page-intro($context,
        xs:string($username-to-update),
        (i18n:val('last-online',$lang) || ': ' || hf:format-dateTime(xs:dateTime($user/xs:string(@last-online))))[$user/@last-online]),
      element div {
        attribute class {'tx-panel'},
        element div {
          attribute class {'tx-panel__header'},
          element h2 {i18n:val('roles',$lang)}
        },
        for $role in tr:roles()/role
        let $name := $role/xs:string(@name),
            $has-role := $user-roles = $name
        return
          element div {
            attribute class {'tx-user-row'},
            element div {
              attribute class {'tx-user-cell'},
              element span {attribute class {'tx-role-pill'}, $name},
              element span {
                attribute class {'tx-muted'},
                ' (' || string-join(for $right in $role/right return ($right/@name,$right/@matches),', ') || ')'
              }
            },
            element div {
              attribute class {'tx-user-actions'},
              if ($has-role)
              then element a {
                attribute class {'tx-link-btn tx-link-btn--danger'},
                attribute href {config:url('/' || $lang || '/users/' || $username-to-update || '/roles/' || $name || '/remove?url=' || $url || '&amp;return-url=' || $return-url)},
                '[' || i18n:val('remove',$lang) || ']'
              }
              else if (ui:check-only('u:mgmt'))
              then element a {
                attribute class {'tx-link-btn'},
                attribute href {config:url('/' || $lang || '/users/' || $username-to-update || '/roles/' || $name || '/add?url=' || $url || '&amp;return-url=' || $return-url)},
                '[' || i18n:val('add',$lang) || ']'
              }
              else ()
            }
          }
      },
      element div {
        attribute class {'tx-panel'},
        element div {
          attribute class {'tx-panel__header'},
          element h2 {i18n:val('sessions',$lang)}
        },
        if (count($session-ids) eq 0)
        then element p {attribute class {'tx-muted'}, i18n:val('no-sessions',$context?lang)}
        else
          for $id in $session-ids
          return
            element div {
              attribute class {'tx-user-row'},
              element div {
                attribute class {'tx-user-cell'},
                element span {attribute class {'tx-mono'}, $id}
              },
              element div {
                attribute class {'tx-user-actions'},
                element a {
                  attribute class {'tx-link-btn tx-link-btn--danger'},
                  attribute href {config:url('/' || $lang || '/users/' || $username-to-update || '/sessions/' || $id || '/close?url=' || $url || ('&amp;return-url=' || $return-url)[$return-url])},
                  i18n:val('delete',$lang)
                }
              }
            }
      },
      element div {
        attribute class {'tx-panel'},
        element h2 {i18n:val('password',$lang)},
        element form {
          attribute method {'POST'},
          attribute action {'/' || $lang || '/users/' || $username-to-update || '/password/reset?url=' || $url || ('&amp;return-url=' || $return-url)[$return-url]},
          element div {
            attribute class {'tx-form-grid'},
            element label {
              i18n:val('old-password',$lang),
              element input {
                attribute type {'password'},
                attribute name {'old-password'},
                attribute required {''}
              }
            },
            element label {
              i18n:val('new-password',$lang),
              element input {
                attribute type {'password'},
                attribute name {'new-password'},
                attribute required {''}
              }
            },
            element div {
              element button {
                attribute class {'tx-btn tx-btn--primary'},
                attribute type {'submit'},
                element span {i18n:val('submit',$lang)}
              }
            }
          }
        }
      }
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
      $right := tr:endpoint-right($url)[1],
      $username := ui:access-session('username'),
      $context := map {'title': $title, 'lang': $lang, 'url':$url,'username':$username},
      $online-users as xs:string* := (job:execute($ns:data || 'data:get-online-users()'),$username)
  return (
    ui:check($right, $lang, $url),
    ui:page(
      $context,
      (
        ui:page-intro($context,
          i18n:val('user-preferences',$lang),
          'Zugänge und Rollen für transpectUI verwalten.'),
        element div {
          attribute class {'tx-panel'},
          element div {
            attribute class {'tx-panel__header'},
            element h2 {ui:icon('user', 17), element span {'Benutzer'}},
            element span {attribute class {'tx-panel__sub'}, xs:string(count(u:users()/user)) || ' Benutzer'}
          },
          element div {
            attribute class {'tx-user-table__head'},
            element span {i18n:val('username',$lang)},
            element span {i18n:val('roles',$lang)},
            element span {i18n:val('status',$lang)},
            element span {i18n:val('actions',$lang)}
          },
          for $user in u:users()/user
          return
            element div {
              attribute class {'tx-user-row'},
              element div {
                attribute class {'tx-user-cell'},
                element span {
                  attribute class {'tx-avatar tx-avatar--small'},
                  upper-case(substring($user/username,1,1))
                },
                element a {
                  attribute href {config:url('/' || $lang || '/users/' || $user/username)},
                  xs:string($user/username)
                }
              },
              element div {
                for $role in u:roles-for-username(xs:string($user/username))
                return element span {attribute class {'tx-role-pill'}, $role}
              },
              ui:status-badge(if ($online-users = $user/username) then 'running' else 'canceled', $lang,
                              if ($online-users = $user/username) then i18n:val('online',$lang) else i18n:val('offline',$lang)),
              element div {
                attribute class {'tx-user-actions'},
                element a {
                  attribute class {'tx-icon-btn'},
                  attribute href {config:url('/' || $lang || '/users/' || $user/username)},
                  attribute aria-label {'Bearbeiten'},
                  attribute title {'Bearbeiten'},
                  ui:icon('settings', 16)
                },
                element a {
                  attribute class {'tx-icon-btn tx-icon-btn--danger'},
                  attribute href {config:url('/' || $lang || '/users/' || $user/username || '/delete?url=' || $url)},
                  attribute aria-label {i18n:val('delete',$lang)},
                  attribute title {i18n:val('delete',$lang)},
                  ui:icon('trash', 16)
                }
              }
            }
        },
        element div {
          attribute class {'tx-panel tx-create-user'},
          element h2 {i18n:val('new-user',$lang)},
          element form {
            attribute method {'POST'},
            attribute action {'/' || $lang || '/users/new?url=' || $url},
            element div {
              attribute class {'tx-form-grid'},
              element label {
                i18n:val('username',$lang),
                element input {
                  attribute type {'text'},
                  attribute name {'username'},
                  attribute required {''}
                }
              },
              element label {
                i18n:val('password',$lang),
                element input {
                  attribute type {'password'},
                  attribute name {'password'},
                  attribute required {''}
                }
              },
              element div {
                attribute class {'tx-create-actions'},
                element button {
                  attribute class {'tx-btn tx-btn--primary'},
                  attribute type {'submit'},
                  ui:icon('plus', 16),
                  element span {i18n:val('submit',$lang)}
                }
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

(: ---------- Design-Bausteine (Redesign v2, le-tex) ---------- :)

declare %private function ui:icon($name as xs:string, $size as xs:integer := 18) {
  element svg {
    (attribute viewBox {'0 0 24 24'},
     attribute fill {'none'},
     attribute stroke {'currentColor'},
     attribute stroke-width {'1.8'},
     attribute stroke-linecap {'round'},
     attribute stroke-linejoin {'round'},
     attribute width {$size},
     attribute height {$size},
     attribute aria-hidden {'true'}),
    (switch ($name)
      case 'upload' return (element path {attribute d {'M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4'}},
                            element polyline {attribute points {'17 8 12 3 7 8'}},
                            element line {attribute x1 {'12'}, attribute y1 {'3'}, attribute x2 {'12'}, attribute y2 {'15'}})
      case 'x' return (element line {attribute x1 {'18'}, attribute y1 {'6'}, attribute x2 {'6'}, attribute y2 {'18'}},
                       element line {attribute x1 {'6'}, attribute y1 {'6'}, attribute x2 {'18'}, attribute y2 {'18'}})
      case 'chevron-right' return element polyline {attribute points {'9 18 15 12 9 6'}}
      case 'chevron-down' return element polyline {attribute points {'6 9 12 15 18 9'}}
      case 'download' return (element path {attribute d {'M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4'}},
                              element polyline {attribute points {'7 10 12 15 17 10'}},
                              element line {attribute x1 {'12'}, attribute y1 {'15'}, attribute x2 {'12'}, attribute y2 {'3'}})
      case 'file' return (element path {attribute d {'M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z'}},
                          element polyline {attribute points {'14 2 14 8 20 8'}})
      case 'refresh' return (element path {attribute d {'M21 12a9 9 0 1 1-2.64-6.36L21 8'}},
                             element polyline {attribute points {'21 3 21 8 16 8'}})
      case 'alert' return (element path {attribute d {'M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z'}},
                           element line {attribute x1 {'12'}, attribute y1 {'9'}, attribute x2 {'12'}, attribute y2 {'13'}},
                           element line {attribute x1 {'12'}, attribute y1 {'17'}, attribute x2 {'12'}, attribute y2 {'17.01'}})
      case 'shield' return (element path {attribute d {'M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z'}},
                            element polyline {attribute points {'9 12 11 14 15 10'}})
      case 'user' return (element circle {attribute cx {'12'}, attribute cy {'8'}, attribute r {'4'}},
                          element path {attribute d {'M4 21v-1a7 7 0 0 1 16 0v1'}})
      case 'logout' return (element path {attribute d {'M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4'}},
                            element polyline {attribute points {'16 17 21 12 16 7'}},
                            element line {attribute x1 {'21'}, attribute y1 {'12'}, attribute x2 {'9'}, attribute y2 {'12'}})
      case 'settings' return (element circle {attribute cx {'12'}, attribute cy {'12'}, attribute r {'3'}},
                              element path {attribute d {'M12 1v4m0 14v4M4.22 4.22l2.83 2.83m9.9 9.9 2.83 2.83M1 12h4m14 0h4M4.22 19.78l2.83-2.83m9.9-9.9 2.83-2.83'}})
      case 'info' return (element circle {attribute cx {'12'}, attribute cy {'12'}, attribute r {'10'}},
                          element line {attribute x1 {'12'}, attribute y1 {'16'}, attribute x2 {'12'}, attribute y2 {'12'}},
                          element line {attribute x1 {'12'}, attribute y1 {'8'}, attribute x2 {'12.01'}, attribute y2 {'8'}})
      case 'plus' return (element line {attribute x1 {'12'}, attribute y1 {'5'}, attribute x2 {'12'}, attribute y2 {'19'}},
                          element line {attribute x1 {'5'}, attribute y1 {'12'}, attribute x2 {'19'}, attribute y2 {'12'}})
      case 'check' return element polyline {attribute points {'20 6 9 17 4 12'}}
      case 'trash' return (element polyline {attribute points {'3 6 5 6 21 6'}},
                           element path {attribute d {'M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2'}})
      case 'clock' return (element circle {attribute cx {'12'}, attribute cy {'12'}, attribute r {'10'}},
                           element polyline {attribute points {'12 6 12 12 16 14'}})
      case 'menu' return (element line {attribute x1 {'3'}, attribute y1 {'6'}, attribute x2 {'21'}, attribute y2 {'6'}},
                          element line {attribute x1 {'3'}, attribute y1 {'12'}, attribute x2 {'21'}, attribute y2 {'12'}},
                          element line {attribute x1 {'3'}, attribute y1 {'18'}, attribute x2 {'21'}, attribute y2 {'18'}})
      case 'arrow-right' return (element line {attribute x1 {'5'}, attribute y1 {'12'}, attribute x2 {'19'}, attribute y2 {'12'}},
                                 element polyline {attribute points {'12 5 19 12 12 19'}})
      default return element circle {attribute cx {'12'}, attribute cy {'12'}, attribute r {'4'}})
  }
};

declare function ui:status-badge($status as xs:string?, $lang as xs:string, $label as xs:string? := ()) {
  let $tone := switch ($status)
                case 'running' return 'info'
                case 'pending' return 'warning'
                case 'stopped' return 'success'
                case 'canceled' return 'neutral'
                case 'error' return 'danger'
                default return 'neutral'
  return element span {
    attribute class {'tx-status tx-status--' || $tone},
    element span {attribute class {'tx-status__dot'}},
    ($label, i18n:val($status, $lang))[1]
  }
};

declare %private function ui:page-intro($context as map(*), $title as xs:string, $description as xs:string?, $up-btn as xs:string? := ()) {
  element div {
    attribute class {'tx-page-intro'},
    element div {
      element h1 {$title},
      element p {$description}[$description]
    },
    element a {
      attribute class {'tx-btn tx-btn--secondary'},
      attribute href {config:url('/' || $context?lang || string-join(tokenize($context?url,'/')[position() ne last()],'/'))},
      element span {$up-btn}
    }[exists($up-btn)]
  }
};

declare %private function ui:breadcrumbs($context as map(*)) {
  if ($context?hide-login or not($context?url) or $context?url eq '/' or $context?url eq '/login') then ()
  else
    let $parts := ($context?url => tokenize('/'))[normalize-space(.)]
    return if (count($parts) le 1) then ()
    else
      element nav {
        attribute class {'tx-breadcrumb'},
        attribute aria-label {'Breadcrumb'},
        element a {attribute href {config:url('/' || $context?lang)}, i18n:val('start',$context?lang)},
        for $part at $i in $parts[position() ne last()]
        let $href := string-join(('',$parts[position() le $i]),'/'),
            $allowed := ui:can-do($context?username, $href)
        return (ui:icon('chevron-right', 14),
                ui:create-anchor($context, $part, '/' || $context?lang || $href,(),$allowed)),
        ui:icon('chevron-right', 14),
        element strong {($context?title[normalize-space(.)], $parts[last()])[1]}
      }
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
    attribute class {'tx-run-row tx-run-row--empty'},
    element span {i18n:static-replacement($tag,$lang)}
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
      (
        ui:page-intro($context,
          i18n:val('conversions',$context?lang),
          xs:string($converter/@name) || ' · ' || i18n:val('auto-refresh',$context?lang),
          i18n:val('new-conversion',$context?lang)),
        element div {
          attribute class {'tx-runs-table'},
          element div {
            attribute class {'tx-table-head'},
            element span {i18n:val('status',$context?lang)},
            element span {'Datei / Run-ID'},
            element span {i18n:val('username',$context?lang)},
            element span {i18n:val('start',$context?lang)},
            element span {i18n:val('actions',$context?lang)}
          },
          element div {
            attribute class {'tx-group-label'},
            i18n:val('pending-conversions',$context?lang),
            element span {xs:string(count($pending-runs))},
            if (count($pending-runs) eq 0)
            then ui:empty-run-info('empty-pending',$context?lang)
            else
              for $run in $pending-runs
              order by xs:dateTime($run/start/text()) descending
              return ui:run-info-display($run, $converter, $context)
          },
          element div {
            attribute class {'tx-group-label'},
            i18n:val('running-conversions',$context?lang),
            element span {xs:string(count($running-runs))},
            if (count($running-runs) eq 0)
            then ui:empty-run-info('empty-running',$context?lang)
            else
              for $run in $running-runs
              order by xs:dateTime($run/start/text()) descending
              return ui:run-info-display($run, $converter, map:put($context,'progress',true()))
          },
          element div {
            attribute class {'tx-group-label'},
            i18n:val('finished-conversions',$context?lang),
            element span {xs:string(count($finished-runs))},
            if (count($finished-runs) eq 0)
            then ui:empty-run-info('empty-finished',$context?lang)
            else
              for $run in $finished-runs
              order by xs:dateTime($run/start/text()) descending
              return ui:run-info-display($run, $converter, $context)
          }
        }
      )
    )
};

declare function ui:run-info-display($run as element(run), $converter as element(converter), $context as map(*)){
  let $runid as xs:string := $run/runid,
      $filename:= $run/filename,
      $start as xs:dateTime := xs:dateTime($run/start),
      $status as xs:string? := $run/status/text(),
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
        else '/' ||$context?lang || '/converter/' || $converter/@id,
      $status-label := i18n:val($status,$context?lang) ||
        (' · ' || format-number($progress,'0%'))[xs:boolean($context?progress) and exists($converter/progress/@max) and $progress gt 0]
  return
    element div {
      attribute class {'tx-run-row'},
      element div {
        attribute class {'tx-run-status'},
        ui:status-badge($status, $context?lang, $status-label),
        element div {
          attribute class {'tx-progress'},
          element span {
            attribute style {'width:' || xs:string(round($progress * 100)) || '%'}
          }
        }[xs:boolean($context?progress) and $progress gt 0]
      },
      element a {
        attribute class {'tx-run-file'},
        attribute href {config:url($converter-url || '/runs/' || $runid)},
        element span {attribute class {'tx-mono'}, $runid},
        element strong {$filename}
      },
      element span {attribute class {'tx-run-user'}, ($username, '–')[1]},
      element span {attribute class {'tx-run-time'}, hf:format-dateTime($start)},
      element div {
        attribute class {'tx-run-actions'},
        element a {
          attribute class {'tx-link-btn'},
          attribute href {config:url($converter-url || '/runs/' || $runid)},
          if ($status eq 'running') then i18n:static-replacement('logs',$context?lang) else i18n:static-replacement('results',$context?lang)
        },
        element a {
          attribute class {'tx-link-btn tx-link-btn--danger'},
          attribute href {config:url($converter-url || '/runs/' || $runid || '/cancel' || '?url=/' || $context?lang || $context?url)},
          i18n:static-replacement('cancel',$context?lang)
        }[not($status = ('stopped','canceled'))]
      }
    }
};

declare function ui:build-run-page($converter as element(converter), $run as element(run), $context as map(xs:string,item()*), $worker as element(worker)? := ()){
  ( ui:check('', $context?lang, $context?url),
    let $status as xs:string := $run/status,
        $is-running as xs:boolean := $status eq 'running' or $status eq 'pending',
        $parameters as xs:string* := $run/params/line,
        $runid as xs:string := $run/runid,
        $title as xs:string? := $run/filename,
        $is-allowed as xs:boolean := tr:allowed($converter, ui:access-session('username'),$run),
        $start as xs:dateTime := xs:dateTime($run/start),
        $end as xs:dateTime? := if (exists($run/end)) then xs:dateTime($run/end) else (),
        $duration := if (exists($end)) then $end - $start else current-dateTime() - $start,
        $logs as element(line)* := tr:get-file-logs($run, $converter, $worker),
        $job-results := tr:get-job-messages($run, $converter, $worker)/*,
        $job-errors := tr:get-job-errors($run, $converter, $worker),
        $result-files as element(file)*:= tr:get-result-files($run, $converter, $worker),
        $is-worker as xs:boolean := exists($worker),
        $run-url-suffix :=
          if ($is-worker)
          then '/worker/' || $converter/@worker || '/converter/' || $converter/@id || '/runs/' || $runid
          else '/converter/' || $converter/@id || '/runs/' || $runid,
        $refresh := if ($is-running) then 5 else (),
        $context := map:merge(($context, map {'refresh': $refresh}))
    return
      ui:page(
        $context,
        (
          element div {
            attribute class {'tx-detail-head'},
            element div {
              ui:status-badge($status, $context?lang),
              element h1 {$title},
              element p {
                element span {attribute class {'tx-mono'}, 'Run-ID ' || $runid},
                element span {hf:format-dateTime($start)},
                element span {hf:format-duration($duration)}
              }
            },
            element div {
              attribute class {'tx-detail-head__actions'},
              element a {
                attribute class {'tx-btn tx-btn--danger-outline'},
                attribute href {config:url($runid || '/cancel' || '?url=/' || $context?lang || $context?url)},
                ui:icon('x', 16),
                element span {i18n:val('cancel',$context?lang)}
              }[not($run/status = ('stopped','canceled'))],
              element a {
                attribute class {'tx-btn tx-btn--secondary'},
                attribute href {config:url('/' || $context?lang || string-join(tokenize($context?url,'/')[position() ne last()],'/'))},
                element span {i18n:val('back-to-list',$context?lang)}
              }
            }
          },
          element div {
            attribute class {'tx-accordions'},
            element details {
              attribute class {'tx-accordion'},
              if ($status eq 'running') then attribute open {} else (),
              element summary {
                attribute class {'tx-accordion__trigger'},
                element span {
                  element span {ui:icon('clock', 18), element strong {i18n:val('logs',$context?lang) || ' (' || count($logs) || ')'}}
                },
                ui:icon('chevron-down', 18)
              },
              element div {
                attribute class {'tx-accordion__content'},
                element div {
                  attribute class {'tx-log'},
                  attribute aria-live {'polite'},
                  if (count($logs) eq 0)
                  then element div {element time {'–'}, element span {i18n:val('pending',$context?lang)}}
                  else
                    for $log at $index in $logs
                    return element div {
                      attribute class {'is-current'[$index eq count($logs)]},
                      element time {hf:format-dateTime($log/@time)},
                      element span {$log/text()}
                    }
                },
                element div {
                  attribute class {'tx-log-note'},
                  element span {attribute class {'tx-pulse'}},
                  element span {i18n:val('automatic-update',$context?lang)}
                }[$is-running]
              }
            },
            element details {
              attribute class {'tx-accordion'},
              element summary {
                attribute class {'tx-accordion__trigger'},
                element span {
                  element span {ui:icon('settings', 18), element strong {i18n:val('parameters',$context?lang)}}
                },
                ui:icon('chevron-down', 18)
              },
              element div {
                attribute class {'tx-accordion__content'},
                element dl {
                  attribute class {'tx-definition-list'},
                  for $p in $parameters
                  let $key := tokenize($p,'=')[1],
                      $value := substring-after($p,'=')
                  return (element dt {attribute class {'tx-mono'}, $key},
                          element dd {$value})
                }
              }
            },
            element details {
              attribute class {'tx-accordion'},
              if ($status eq 'stopped') then attribute open {} else (),
              element summary {
                attribute class {'tx-accordion__trigger'},
                element span {
                  element span {ui:icon('download', 18), element strong {i18n:val('results',$context?lang) || ' (' || count($result-files) || ')'}}
                },
                ui:icon('chevron-down', 18)
              },
              element div {
                attribute class {'tx-accordion__content'},
                if (count($result-files) eq 0)
                then element p {attribute class {'tx-muted'}, i18n:val('no-results',$context?lang)}
                else
                  element div {
                    attribute class {'tx-result-list'},
                    for $file at $index in $result-files
                    let $name := xs:string($file/@name),
                        $is-report := $index eq 1 and matches($name,'\.(x?html)$')
                    return
                      element div {
                        attribute class {'tx-result-row' || ' is-featured'[$is-report]},
                        ui:icon('file', 20),
                        element div {
                          element strong {$name}
                        },
                        element a {
                          attribute class {'tx-btn tx-btn--secondary'},
                          attribute href {config:url('/' || $context?lang || $run-url-suffix || '/show/' || $name)},
                          attribute target {'_blank'},
                          element span {i18n:val('show-report',$context?lang)}
                        }[$is-report],
                        element a {
                          attribute class {'tx-icon-btn'},
                          attribute href {config:url('/' || $context?lang || $run-url-suffix || '/download/' || $name)},
                          attribute download {$name},
                          attribute aria-label {i18n:val('download',$context?lang) || ': ' || $name},
                          attribute title {i18n:val('download',$context?lang)},
                          ui:icon('download', 17)
                        }
                      }
                  }
              }
            },
            element details {
              attribute class {'tx-accordion'},
              element summary {
                attribute class {'tx-accordion__trigger'},
                element span {
                  element span {ui:icon('info', 18), element strong {i18n:val('job-messages',$context?lang) || ' (' || (count($job-errors) + count($job-results)) || ')'}}
                },
                ui:icon('chevron-down', 18)
              },
              element div {
                attribute class {'tx-accordion__content'},
                if (count($job-errors) + count($job-results) eq 0)
                then element p {attribute class {'tx-muted'}, i18n:val('no-messages',$context?lang)}
                else
                  element ol {
                    attribute class {'tx-message-list'},
                    for $m in $job-errors
                    return element li {attribute class {'is-error'}, $m},
                    for $m in $job-results
                    return element li {$m}
                  }
              }
            }
          }
        )
      )
  )
};

declare function ui:build-converter-page($converter as element(converter), $context as map(xs:string, item()*)) {
  ui:check($context?right, $context?lang, $context?url),
  ui:page(
    $context,
    (
      ui:page-intro($context,
        $converter/xs:string(@name),
        ($converter/xs:string(@description), i18n:val('upload',$context?lang))[1]),
      element form {
        attribute class {'tx-form-card'},
        attribute action {config:url('/' || $context?lang || $context?url || '/convert')},
        attribute method {'POST'},
        attribute enctype {"multipart/form-data"},
        element div {
          attribute class {'tx-form-grid'},
          for $p in $converter/inputs/*
          return hf:parameter-to-html($p, $context?lang)
        },
        element label {
          attribute class {'tx-dropzone'},
          attribute id {'dropZone'},
          element input {
            attribute type {'file'},
            attribute id {'fileInput'},
            attribute name {'upload_file_uploaded_data'},
            attribute accept {xs:string($converter/input-file-ext/@allowed)}[exists($converter/input-file-ext/@allowed)]
          },
          element span {ui:icon('upload', 34)},
          element strong {i18n:val('dragDrop',$context?lang)},
          element span {i18n:val('clickToChoose',$context?lang)},
          element small {$converter/input-file-ext/description[@lang eq $context?lang]}[$converter/input-file-ext/description[@lang eq $context?lang]]
        },
        element div {
          attribute class {'tx-form-footer'},
          ui:create-anchor(
            $context,
            i18n:val('prev-conversions',$context?lang),
            '/' || $context?lang || $context?url || '/runs', 'tx-text-btn',
            ui:can-do($context?username, $context?url || '/runs')
          ),
          element button {
            attribute id {'submit-to-conversion'},
            attribute disabled {},
            attribute class {'tx-btn tx-btn--primary'},
            attribute type {'submit'},
            element span {i18n:val('submit-file',$context?lang)},
            ui:icon('arrow-right', 17)
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
      element div {
        attribute class {'tx-app'},
        ui:get-html-header($context),
        element main {
          attribute class {'tx-main' || ' tx-main--center'[$context?hide-login or $context?center]},
          ui:breadcrumbs($context),
          $content,
          $description
        }
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
      string-join(($context?status,$context?title),' ') ! normalize-space(.)
    },
    element link {
      attribute rel {"stylesheet"},
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
  if ($context?hide-login) then () else
  element header {
    attribute class {'tx-header'},
    element div {
      attribute class {'tx-header__inner'},
      element button {
        attribute class {'tx-mobile-menu'},
        attribute aria-label {'Menü öffnen'},
        ui:icon('menu', 20)
      },
      element a {
        attribute class {'tx-brand'},
        attribute href {config:url('/' || $context?lang)},
        attribute title {i18n:val('start',$context?lang)},
        element span {
          attribute class {'tx-logo'},
          element span {'trans'},
          element b {'pect'}
        }
      },
      element nav {
        attribute class {'tx-main-nav'},
        attribute aria-label {'Hauptnavigation'},
        element a {
          attribute href {config:url('/' || $context?lang)},
          attribute class {'is-active'[not($context?url) or $context?url eq '/' or $context?url eq '']},
          i18n:val('start',$context?lang)
        }
      },
      element div {
        attribute class {'tx-header__tools'},
        element div {
          attribute class {'tx-languages'},
          for $language in $i18n:languages//language
          return element a {
            attribute href {config:url('/' || $language/xs:string(@short) || $context?url)},
            attribute class {'is-active'[$language/xs:string(@short) eq $context?lang]},
            attribute title {$language/xs:string(@name)},
            upper-case($language/xs:string(@short))
          }
        },
        if (session:get('username'))
        then
          element div {
            attribute class {'tx-user-menu'},
            element button {
              attribute class {'tx-user-trigger'},
              attribute aria-haspopup {'true'},
              attribute aria-expanded {'false'},
              element span {attribute class {'tx-avatar'}, upper-case(substring(xs:string(session:get('username')),1,1))},
              element span {attribute class {'tx-user-name'}, xs:string(session:get('username'))},
              ui:icon('chevron-down', 15)
            },
            element div {
              attribute class {'tx-popover'},
              element a {
                attribute href {config:url('/' || $context?lang || '/users/' || session:get('username') || '?return-url=' || config:url($context?url))},
                ui:icon('user', 15),
                i18n:val('user-preferences',$context?lang)
              },
              element a {
                attribute href {config:url('/' || $context?lang || '/admin')},
                ui:icon('settings', 15),
                'Admin'
              }[ui:can-do($context?username, '/' || $context?lang || '/admin')],
              element a {
                attribute href {config:url('/' || $context?lang || '/logout?url=' || config:url('/' || $context?lang || $context?url))},
                ui:icon('logout', 15),
                i18n:static-replacement('logout', $context?lang)
              }
            }
          }
        else hf:create-anchor(config:url('/' || $context?lang || '/login?url=' || config:url('/' || $context?lang || $context?url)),i18n:static-replacement('login', $context?lang),'tx-login-link')
      }
    }
  }
};

declare function ui:can-do($username,$url as xs:string) {
  let $can := tr:can-do($username,tr:endpoint-right($url)[1], tr:endpoint-owner($url)),
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
    attribute class {'tx-stacked-bar ' || $class},
    let $sum as xs:decimal := sum($vals ! xs:decimal(?value))
    return
      for $v at $i in $vals
      let $value := xs:decimal($v?value),
          $display :=
            if (exists($value) and $sum gt 0)
            then (if ($mem) then prof:human($value * 1024) else xs:string(round($value)) || '%') || ' (' || $v?name || ')'
            else 'EMPTY'
      return
        element span {
          attribute class {'tx-segment tx-segment--' || (($i - 1) mod 3)},
          attribute style {'width:' || xs:string(if ($sum gt 0) then ($value div $sum) * 100 else 0) || '%;'},
          attribute title {$display}
        }
  }
};