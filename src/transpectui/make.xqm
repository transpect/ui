module namespace make = 'http://le-tex.de/make';
import module namespace ns = 'http://le-tex.de/namespaces' at 'namespaces.xqm';
import module namespace conv = 'http://le-tex.de/converter' at 'converter.xqm';
import module namespace config = 'http://le-tex.de/config' at 'config.xqm';
import module namespace hf = 'http://le-tex.de/helper-functions' at 'helper-functions.xqm';
import module namespace i18n = 'http://le-tex.de/i18n' at 'i18n.xqm';
import module namespace st = 'http://le-tex.de/store' at 'store.xqm';

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
      $title := 'Konvertierungen',
      $url as xs:string := '/converter/' || $converter-id || '/runs',
      $context := map {'converter-id': $converter-id, 'title': $title, 'lang': $lang, 'url':$url}
  return
    element html {
      config:get-html-head($context),
      element body {
        config:get-html-header($context),
        element div {
          attribute class {'well'},
          element span {
            attribute class {'date'},
            'abgerufen: ' || hf:format-dateTime(current-dateTime())
          },
          for $runid in map:keys($runs)
          let $run as map(*) :=$runs?$runid, 
              $parameters as xs:string* := $run?params,
              $filename as xs:string? := $run?filename,
              $is-running as xs:boolean := xs:boolean($run?running),
              $start as xs:dateTime := xs:dateTime($run?start),
              $running-text := if ($is-running) then i18n:static-replacement('running',$lang) else i18n:static-replacement('stopped',$lang)
          order by $start descending
          order by $is-running descending
          return (
            element details {
              element summary {hf:format-dateTime($start) || ' - ' ||$filename || ' (' || $runid || ') ' || $running-text},
              element div {
                attribute class {'make-parameters'},
                element ul {
                  for $p in $parameters
                  return
                    element li {
                      $p
                    }
                }
              },
              element div {
                attribute class {'make-logs'}
              },
              element div {
                attribute class {'make-links'},
                hf:create-anchor('/' ||$lang || '/converter/' || $converter-id || '/log/' || $runid, i18n:static-replacement("logs",$lang))
              }
            }
          )
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
  %rest:path("/{$lang}/converter/{$converter-id}/log")
  %output:method("html")
  %output:html-version('5')
function make:logs($converter-id as xs:string, $lang as xs:string){
  let $runs := make:get-runs(),
      $title as xs:string? := "Konvertierungen",
      $url := '/converter/' || $converter-id || '/log/',
      $refresh := 10,
      $context := map {'converter-id': $converter-id, 'lang': $lang, 'title': $title, 'refresh': $refresh, 'url': $url},
      $run-list := hf:map-to-list($runs)
  return
    element html {
      config:get-html-head($context),
      element body {
        config:get-html-header($context),
        element div {
          attribute class {'well'},
          for $runid in map:keys($runs)
          let $run := $runs?$runid
          return
            hf:create-anchor($url || $runid, $runid || ' (' ||$run?converter || ')', 'block')
        }
      }
    }
};

declare
  %rest:GET
  %rest:path("/{$lang}/converter/{$converter-id}/log/{$runid}")
  %output:method("html")
  %output:html-version('5')
function make:log($converter-id as xs:string, $runid as xs:string, $lang as xs:string){
  let $converter as element(converter) := conv:get($converter-id),
      $run-info as map(*) := make:get-runs()?$runid,
      $is-running as xs:boolean := xs:boolean($run-info?running),
      $parameters as xs:string* := $run-info?params,
      $logs as xs:string* := make:get-logs($runid),
      $title as xs:string? := i18n:val('logs',$lang) || ': ' || $run-info?filename,
      $url := '/converter/' || $converter-id || '/log/' || $runid,
      $refresh := if ($is-running) then 5 else (),
      $context := map {'converter-id': $converter-id, 'lang': $lang, 'title': $title, 'refresh': $refresh, 'url': $url},
      $log-dir := (($run-info?file => tokenize('/'))[position() ne last()] => string-join('/')) || '/debug/status',
      $logs :=
        if (file:exists($log-dir))
        then
          for $file in file:list($log-dir)
          let $mod-by := file:last-modified($log-dir || '/' || $file)
          order by $mod-by
          where file:exists($log-dir || '/' ||$file)
          return map {'text': file:read-text($log-dir || '/' ||$file),'time': $mod-by}
        else ()
  return
    element html {
      config:get-html-head($context),
      element body {
        config:get-html-header($context),
        element div {
          element div {
            attribute class {'well'},
            element h3 {if ($is-running) then i18n:val('running',$lang) else i18n:val('stopped',$lang)}
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
          element div {
            attribute class {'make-links well'},
            hf:create-anchor('/' ||$lang || '/converter/' || $converter-id || '/result/' || $runid, i18n:static-replacement("to-results",$lang))
          }
        }
      }
    }
};


declare
  %rest:GET
  %rest:path("/{$lang}/converter/{$converter-id}/result/{$runid}")
  %output:method("html")
  %output:html-version('5')
function make:result($converter-id as xs:string, $runid as xs:string, $lang as xs:string){
  let $converter as element(converter) := conv:get($converter-id),
      $run-info as map(*) := make:get-runs()?$runid,
      $is-running as xs:boolean := xs:boolean($run-info?running),
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
      $url := '/converter/' || $converter-id || '/log/' || $runid,
      $refresh := if ($is-running) then 1 else (),
      $context := map {'converter-id': $converter-id, 'lang': $lang, 'title': $run-info?filename, 'refresh': $refresh, 'url': $url},
      $post-conv-actions := conv:get-post-conv-actions($converter),
      $out-path := st:get('params', $runid)[matches(.,'OUT_DIR')] ! tokenize(.,'=')[2],
      $result-files :=
        for $file in file:list($out-path)
        where not(matches($file,'/$')) and not(matches($file, '\.pid$|\.stdout$'))
        return {'name': $file, 'path': $out-path || $file}
  return
    element html {
      config:get-html-head($context),
      element body {
        config:get-html-header($context),
        element div {
          element div {
            attribute class {'well'},
            element h3 {if ($is-running) then i18n:val('running',$lang) else i18n:val('stopped',$lang)}
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
            return element div {
              attribute class {'line d-flex'},
              element div {
                attribute class {'filename'},
                element a {
                  attribute href {'/run/' ||$runid || '/download/' || $file?name},
                  attribute download {$file?name},
                  $file?name}},
              element div {
                attribute class {'actions'},
                for $action in $post-conv-actions
                where matches($file?name, $action/xs:string(@regex))
                return
                  element input{
                    attribute type {'button'},
                    attribute value {$action/xs:string(@message)}
                  }
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

declare function make:start-target-run($targetname as xs:string, $converter as element(converter), $target-parameters as map(xs:string,xs:string), $files as map(xs:string, xs:base64Binary)) as xs:string {
  let $makefile := conv:get-makefile($converter),
      $runid := hf:id(),
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
              map {'IN_FILE':$filepath}
            ))
          )
      ),
      
      $store := st:set('params', $runid, $parameters),
      
      $job-id := hf:eval((), "proc:fork('make',$parameters,$options)", map {'parameters':$parameters,'options':$options}, map {'cache':true(), 'id':hf:id('make-target')}),
      $wait := prof:sleep(1000),
      $pid := normalize-space(file:read-text($filepath|| '.pid')),
      $store := st:set('pid', $runid, $pid),
      $store-logs := st:set('logs', $runid, element run {attribute run {$runid},element logs {}})
  return $runid
};

declare function make:format-target-parameters($target-parameters as map(xs:string,xs:string)) as xs:string*{
  for $k in map:keys($target-parameters)
  return upper-case($k) || '=' || $target-parameters?$k
};

declare function make:build-target-dir($converter as element(converter), $filename as xs:string, $suffix as xs:string){
  let $converter-id := $converter/@id
  return $config:data-dir-base || '/' || $converter-id || '/' || $filename || '_' || $suffix || '/' 
};

declare function make:check-run($runid as xs:string) as xs:boolean{
  let $pid := st:get('pid',$runid),
      $result as element(result) := proc:execute('ps', ('-a', '-q', $pid))
  return xs:boolean($result/code = '0')
};

declare function make:stop-run($runid as xs:string) as xs:boolean{
  let $pid := st:get('pid',$runid),
      $result as element(result) := proc:execute('kill', ('-9', $pid)),
      $worked := xs:boolean($result/code = '0'),
      $still-running := if (not($worked)) then make:check-run($runid) else false()
  return if ($still-running) then false() else true()
};

declare function make:get-logs($runid){
  st:get('log', $runid)/logs/log
};

declare function make:get-runs() as map(xs:string, map(xs:string,item()*))?{
  map:merge((
    for $k in store:keys()[matches(.,'^start:')]
    let $runid := tokenize($k,':')[2] 
    return
      map {
        $runid : map {
          'running':make:check-run($runid), 
          'filename':st:get('filename', $runid),
          'params':st:get("params", $runid),
          'start':st:get("start", $runid),
          'file':st:get("file", $runid),
          'converter': st:get("converter", $runid)}}
  ))
};

declare function make:get-output($runid as xs:string) as xs:string{
  let $converter-id as xs:string := st:get('converter', $runid),
      $converter as element(converter) := conv:get($converter-id),
      $output-location as xs:string := $converter/output/xs:string(@location)
  return file:read-text($output-location)
};