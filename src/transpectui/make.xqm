module namespace make = 'http://le-tex.de/make';
import module namespace ns = 'http://le-tex.de/namespaces' at 'namespaces.xqm';
import module namespace conv = 'http://le-tex.de/converter' at 'converter.xqm';
import module namespace config = 'http://le-tex.de/config' at 'config.xqm';
import module namespace hf = 'http://le-tex.de/helper-functions' at 'helper-functions.xqm';
import module namespace i18n = 'http://le-tex.de/i18n' at 'i18n.xqm';
import module namespace st = 'http://le-tex.de/store' at 'store.xqm';
import module namespace queue = 'http://le-tex.de/queue' at 'queue.xqm';

(: 
 : wrapper module for the orchestration of convertion runs.
 :)

declare
  %rest:GET
  %rest:path("/{$lang}/converter/{$converter-id}/runs")
  %output:method("html")
  %output:html-version('5')
function make:all-runs($converter-id as xs:string, $lang as xs:string){
  let $runs := make:get-runs(),
      $title := i18n:static-replacement('conversions',$lang),
      $context := map {'title': $title, 'lang': $lang, 'return-url':'/converter/' || $converter-id, 'url':'/converter/'|| $converter-id || '/runs'},
      $running-runs :=
        for $runid in map:keys($runs)
        where xs:boolean($runs?$runid?status eq 'running')
        return $runid,
      $finished-runs :=
        for $runid in map:keys($runs)
        where not(xs:boolean($runs?$runid?status = ('pending','running')))
        return $runid,
      $pending-runs :=
        for $runid in map:keys($runs)
        where xs:boolean($runs?$runid?status eq 'pending')
        return $runid
  return
    element html {
      config:get-html-head($context),
      element body {
        config:get-html-header($context),
        element div {
          attribute class {'well'},
          element div {
            attribute class {'date spacious'},
            i18n:static-replacement('called',$lang) || ': ' || hf:format-dateTime(current-dateTime())
          },
          element div {
            attribute class {'well'},
            i18n:static-replacement('pending-conversions',$lang) || ':',
            if (count($pending-runs) eq 0)
            then make:empty-run-info('empty-pending',$lang)
            else
              for $runid in $pending-runs
              let $run as map(*) :=$runs?$runid
              order by $run?start descending
              return make:run-info-display($runid, $run, $lang, $converter-id)
          },
          element div {
            attribute class {'well'},
            i18n:static-replacement('running-conversions',$lang) || ':',
            if (count($running-runs) eq 0)
            then make:empty-run-info('empty-running',$lang)
            else
              for $runid in $running-runs
              let $run as map(*) :=$runs?$runid
              order by $run?start descending
              return make:run-info-display($runid, $run, $lang, $converter-id)
          },
          element div {
            attribute class {'well'},
            i18n:static-replacement('finished-conversions',$lang) || ':',
            if (count($finished-runs) eq 0)
            then make:empty-run-info('empty-finished',$lang)
            else
              for $runid in $finished-runs
              let $run as map(*) :=$runs?$runid
              order by $run?start descending
              return make:run-info-display($runid, $run, $lang, $converter-id)
          }
        }
      }
    }
};

declare
  %rest:PUT
  %rest:path("/log/{$runid}")
  %rest:form-param('texts','{$texts}')
function make:log-for-run($runid, $texts){
  let $texts := tokenize($texts,';'),
      $logs := for $text in $texts return element log {attribute timestamp {xs:string(current-dateTime())}, attribute id {substring(random:uuid(),1,8)}, $text},
      $updated-logs := st:get('log',$runid) update {insert nodes $logs into logs}
  return st:set('log', $runid, $updated-logs)
};

declare
  %rest:GET
  %rest:path("/{$lang}/converter/{$converter-id}/run/{$runid}/cancel")
function make:stop-run-frontend($runid, $lang, $converter-id){
  let $run := make:get-run($runid),
      $cancel := make:stop-run($runid)
  return web:redirect(config:url('/' || $lang ||'/converter/' || $converter-id || '/runs'))
};

declare
  %rest:GET
  %rest:path("/{$lang}/converter/{$converter-id}/run/{$runid}/logs")
  %output:method("html")
  %output:html-version('5')
function make:log($converter-id as xs:string, $runid as xs:string, $lang as xs:string){
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
      $subtitle as xs:string? := hf:format-dateTime(xs:dateTime($run-info?start)),
      $refresh := if ($is-running) then 5 else (),
      $context := map {'lang': $lang, 'title': $title, 'status': $short-status || ' ', 'refresh': $refresh, 'return-url': '/converter/' || $converter-id, 'url': '/converter/' || $converter-id || '/run/' || $runid || '/logs' , 'subtitle':$subtitle},
      $log-dir := (($run-info?file => tokenize('/'))[position() ne last()] => string-join('/')) || '/debug/status',
      $logs := make:get-file-logs($run-info?file)
  return
    if ($is-running)
    then
      element html {
        config:get-html-head($context),
        element body {
          config:get-html-header($context),
          element div {
            element div {
              attribute class {'well'},
              element h3 {i18n:val($status,$lang)}
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
            }
          }
        }
      }
  else web:redirect('../' || $runid || '/result')
};

declare
  %rest:GET
  %rest:path("/{$lang}/converter/{$converter-id}/run/{$runid}/result")
  %output:method("html")
  %output:html-version('5')
function make:result($converter-id as xs:string, $runid as xs:string, $lang as xs:string){
  let $converter as element(converter) := conv:get($converter-id),
      $job-results := make:store-job-messages($runid),
      $run-info as map(*) := make:get-run($runid),
      $status as xs:string := $run-info?status,
      $is-running as xs:boolean := $status eq 'running',
      $parameters as xs:string* := $run-info?params,
      $log-dir := (($run-info?file => tokenize('/'))[position() ne last()] => string-join('/')) || '/debug/status',
      $logs :=
        if (file:exists($log-dir))
        then
          for $file in file:list($log-dir)
          let $mod-by := file:last-modified($log-dir || '/' || $file)
          order by $mod-by
          where file:exists($log-dir || '/' ||$file)
          return map {'text': file:read-text($log-dir || '/' ||$file),'time': $mod-by}
        else (),
      $title as xs:string? := $run-info?filename,
      $subtitle as xs:string? := hf:format-dateTime(xs:dateTime($run-info?start)),
      $refresh := if ($is-running) then 1 else (),
      $context := map {'lang': $lang, 'title': $run-info?filename, 'refresh': $refresh, 'return-url': '/converter/' || $converter-id, 'url': '/converter/' || $converter-id || '/run/' || $runid || '/result', 'subtitle':$subtitle},
      $post-conv-actions := conv:get-post-conv-actions($converter),
      $out-path := st:get('params', $runid)[matches(.,'OUT_DIR')] ! tokenize(.,'=')[2],
      $result-files :=
        for $file in file:list($out-path)
        where not(matches($file,'/$')) and not(matches($file, '\.pid$|\.stdout$'))
        return {'name': normalize-space($file), 'path': $out-path || normalize-space($file)}
  return
    element html {
      config:get-html-head($context),
      element body {
        config:get-html-header($context),
        element div {
          element div {
            attribute class {'well'},
            element h3 {i18n:val($status,$lang)}
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
            if ($is-running) then attribute open {} else (),
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
            attribute open {},
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
                    attribute href {config:url('/run/' ||$runid || '/show/' || $file?name)},
                    attribute target {'_blank'},
                    $file?name}
                else
                  element a {
                    attribute href {config:url('/run/' ||$runid || '/download/' || $file?name)},
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
};


declare
  %rest:GET
  %rest:path("/run/{$runid}/download/{$filename}")
function make:download($runid, $filename) {
  let $outpath := st:get('params', $runid)[matches(.,'OUT_DIR')] ! tokenize(.,'=')[2],
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
function make:show($runid, $filename) {
  let $outpath := st:get('params', $runid)[matches(.,'OUT_DIR')] ! tokenize(.,'=')[2],
      $filepath := $outpath || $filename,
      $filesize := file:size($filepath),
      $extention := ($filename => tokenize('[\./]'))[last()],
      $show-direct as xs:boolean := $extention = ('xhtml','html'),
      $format := $filename ! tokenize('.')[last()],
      $data := if ($show-direct) then doc($filepath) else file:read-binary($filepath),
      $log := admin:write-log($filename || ': ' || $extention || ': ' || xs:string($show-direct))
  return if ($show-direct) then $data else web:error('415','Das Dokument kann nicht angezeigt werden.')
};

declare
  %rest:GET
  %rest:path("/run/{$runid}/{$filename}/action/{$action-name}")
function make:post-conversion-action($runid, $filename, $action-name as xs:string) {
  let $outpath := st:get('params', $runid)[matches(.,'OUT_DIR')] ! tokenize(.,'=')[2],
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

declare function make:start-target-run($targetname as xs:string, $converter as element(converter), $target-parameters as map(xs:string,xs:string), $files as map(xs:string, xs:base64Binary)) as element(run) {
  let $makefile := make:get-makefile-for-target($converter, $targetname),
      $runid := hf:id(),
      $store := st:set('runid', $runid, $runid),
      $store := st:set('start', $runid, current-dateTime()),
      $timestamp := xs:string(current-dateTime()) ! replace(.,':|\.','') ! replace(.,'T','_'),
      $dir := string-join(tokenize($makefile,'/')[position() ne last()],'/'),
      $options := map {'dir':$dir},
      
      $store := st:set('converter', $runid, $converter/xs:string(@id)),
      
      $original-filename as xs:string := map:keys($files)[1],
      $store := st:set('filename', $runid, $original-filename),
      $extension as xs:string := $original-filename ! tokenize(.,'\.')[last()], 
      $filename-base as xs:string :=
        string-join(
          $original-filename ! tokenize(.,'\.')[not(position() eq last())] ! replace(.,"[^0-9A-Za-z_\.-]",'_'),
          '.'),
      $filename := $filename-base || '.' || $extension,
      $target-directory := make:build-target-dir($converter, $filename, $timestamp),
      $filepath as xs:string := $target-directory || $filename,
      $filecontent as xs:base64Binary := $files?$original-filename,
      
      $store := st:set('file', $runid, $filepath),
      
      $log := hf:log('create-dir: ' || $target-directory),
      $mkdir := file:create-dir($target-directory),
      $move-file := file:write-binary($filepath,$filecontent),
      
      $parameters as xs:string+ := (
        $targetname,
        make:format-target-parameters(
          map:merge((
            $target-parameters,
            map {'RUNID': $runid},
            map {'OUT_DIR': $target-directory},
            map {'IN_FILE': $filepath}
          ))
        )
      ),
      
      $store := st:set('params', $runid, $parameters),
      $queue-job :=
        queue:register(
          "declare variable $parameters external; declare variable $options external; proc:execute('make',$parameters,$options)",
          map {'parameters':$parameters,'options':$options},
          map {'cache':true(), 'id':hf:id('make-target')},
          $ns:store || "declare variable $job-id external; st:set('job-id', '" || $runid || "',$job-id)"),
      $wait := prof:sleep(1000),
      $store := st:set('queue-id',$runid,$queue-job?id),
      $has-pid := file:exists($filepath|| '.pid'),
      $pid := if ($has-pid) then normalize-space(file:read-text($filepath|| '.pid')) else (),
      $store := if ($has-pid) then st:set('pid', $runid, $pid) else (),
      $store-logs := if ($has-pid) then st:set('logs', $runid, element run {attribute run {$runid},element logs {}}) else (),
      $is-pending := queue:is-pending($queue-job?id),
      $error-message := (
        if (not($has-pid) and not($is-pending)) then 'Die Konvertierung wurde nicht korrekt gestartet. (Die PID konnte nicht gefunden werden, Job ist nicht in der Warteschlange.)'
      )
  return element run {
           element id {$runid},
           element error {string-join($error-message,' ')} [$error-message]
         }
};

declare function make:store-job-messages($runid as xs:string){
  let $job-id := st:get('job-id',$runid),
      $state := if ($job-id) then job:list-details($job-id)/xs:string(@state) else 'not-found',
      $messages := 
        if ($state eq 'cached')
        then job:result($job-id)/output/text() ! tokenize(.,'\n')
        else st:get('job-results',$runid),
      $store := if ($state eq 'cached')
        then st:set('job-results',$runid, $messages)
        else ()
  return $messages
};

declare function make:start-target($target-name as xs:string, $converter as element(converter), $filepath as xs:string, $runid as xs:string, $parameters as xs:string*) as xs:string {
  let $makefile := make:get-makefile-for-target($converter, $target-name),
      $dir := string-join(tokenize($makefile,'/')[position() ne last()],'/'),
      $options := map {'dir':$dir},
      $log := hf:log('run target ' || $target-name || ' in ' || $makefile,'└'),
      $log := hf:log('run target ' || $target-name || ' in ' || $makefile,'└'),
      
      $log := for $param in $parameters return hf:log('--param: ' || $param,'┃'),
      $log := for $key in map:keys($options) return hf:log('--opt: ' || $key || ': ' || $options?$key,'┃'),
      
      
      $job-id := hf:eval((), "proc:fork('make',$parameters,$options)", map {'parameters':$parameters,'options':$options}, map {'cache':true(), 'id':hf:id('make-target' || $target-name)}),
      $wait := prof:sleep(1000),
      $pid := normalize-space(file:read-text($filepath|| '.pid'))
  return $pid
};

declare function make:format-target-parameters($target-parameters as map(xs:string,xs:string)) as xs:string*{
  for $k in map:keys($target-parameters)
  return upper-case($k) || '=' || $target-parameters?$k
};

declare function make:build-target-dir($converter as element(converter), $filename as xs:string, $suffix as xs:string){
  let $converter-id := $converter/@id
  return $config:data-dir-base || '/' || $converter-id || '/' || $filename || '_' || $suffix || '/' 
};

declare function make:check-run($runid as xs:string) as xs:string{
  let $pid := st:get('pid',$runid),
      $queue-id := st:get('queue-id',$runid), 
      $result as element(result) := proc:execute('ps', ('-a', '-q', $pid)),
      $is-running as xs:boolean := xs:boolean($result/code = '0'),
      $is-pending as xs:boolean := if (array:size(queue:list()) gt 0) then exists(for $job in array:items(queue:list()) where $job?id eq $queue-id return $job) else false()
  return (if ($is-running)
          then 'running'
          else
            if ($is-pending)
            then 'pending'
            else 'stopped'
         )
};

declare function make:stop-run($runid) {
  let $run := (make:get-run($runid),{})[1],
      $status := $run?status
  return
    switch ($status)
    case 'running' return make:stop-running-run($run)
    case 'pending' return make:stop-pending-run($run)
    default return true()
};

declare function make:stop-pending-run($run as map(xs:string,item()*)) {
  let $remove := queue:remove($run?queue-id),
      $set := st:set('status', $run?runid, 'canceled')
  return $remove
};

declare function make:stop-running-run($run as map(xs:string,item()*)) as xs:boolean{
  let $runid := $run?runid,
      $job-id := $run?job-id,
      $result := job:remove($job-id),
      $is-running := not(job:list() = $job-id),
      $set := st:set('status', $run?runid, 'canceled')
  return if ($is-running) then false() else true()
};

declare function make:get-logs($runid){
  st:get('log', $runid)/logs/log
};
declare function make:get-converter($runid) as element(converter)?{
  conv:get(st:get("converter",$runid))
};

declare function make:get-run($runid) as map(xs:string,item()*) {
  map {
    'runid':st:get('runid',$runid),
    'status':(st:get('status', $runid),make:check-run($runid))[1], 
    'filename':st:get('filename', $runid),
    'params':st:get("params", $runid),
    'start':st:get("start", $runid),
    'file':st:get("file", $runid),
    'pid':st:get("pid", $runid),
    'job-id':st:get("job-id", $runid),
    'queue-id':st:get('queue-id',$runid),
    'converter': st:get("converter", $runid)}
};

declare function make:get-runs() as map(xs:string, map(xs:string,item()*))?{
  map:merge (
    for $runid in st:get-runs() ! tokenize(.,'/')[1]
    return
      map {$runid: make:get-run($runid)}
  )
};

declare function make:get-output($runid as xs:string) as xs:string{
  let $converter-id as xs:string := st:get('converter', $runid),
      $converter as element(converter) := conv:get($converter-id),
      $output-location as xs:string := $converter/output/xs:string(@location)
  return file:read-text($output-location)
};

declare function make:get-targets($makefile as element(*)) as element(*)?{
  if (file:exists($makefile/@location))
  then
    $makefile update {
      for $line in tokenize(file:read-text($makefile/@location),'\n')
      let $targets := tokenize($line,'\s') ! replace(.,':','')
      where matches($line, "[a-zA-Z_]+:\s?$")
      return 
        for $t in $targets
        return insert node element target {$t} into .
      }
};

declare function make:extend-converter($converter as element(converter)) as element(converter){
  $converter update {
    for $makefile in (.//makefile, .//webgui-makefile)
    let $extended := make:get-targets($makefile)
    return replace node $makefile with $extended
  }
};

declare function make:get-makefile-for-target($converter as element(converter), $target as xs:string) {
  let $extended := make:extend-converter($converter)
  return $extended//*[target[text() eq $target]]/@location
};


declare function make:empty-run-info($tag, $lang) {
  element div {
    attribute class {'run-info line date'},
    i18n:static-replacement($tag,$lang)
  }
};

declare function make:run-info-display($runid as xs:string, $run, $lang as xs:string, $converter-id as xs:string){
  let $filename as xs:string? := $run?filename,
      $start as xs:dateTime := xs:dateTime($run?start),
      $running-text := i18n:static-replacement($run?status,$lang)
  return 
    element div {
      attribute class {'run-info line'},
      element div {
        attribute class {'run-info running'},
        $running-text,
        hf:create-anchor(config:url('/' ||$lang || '/converter/' || $converter-id || '/run/' || $runid || '/logs'), if ($run?status eq 'running') then i18n:static-replacement("logs",$lang) else i18n:static-replacement("results",$lang))
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
        attribute class {'run-info cancel'},
        hf:create-anchor(config:url('/' ||$lang || '/converter/' || $converter-id || '/run/' || $runid || '/cancel'), i18n:static-replacement("cancel",$lang))
      }[not($run?status = ('stopped','canceled'))]
    }
};

declare function make:get-file-logs($file) {
  let $log-dir := (($file => tokenize('/'))[position() ne last()] => string-join('/')) || '/debug/status',
      $logs :=
        if (file:exists($log-dir))
        then
          for $file in file:list($log-dir)
          let $mod-by := file:last-modified($log-dir || '/' || $file)
          order by $mod-by
          where file:exists($log-dir || '/' ||$file)
          return map {'text': file:read-text($log-dir || '/' ||$file),'time': $mod-by}
        else ()
  return $logs
};