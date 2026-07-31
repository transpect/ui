module namespace make = 'http://le-tex.de/make';
import module namespace ns = 'http://le-tex.de/namespaces' at 'namespaces.xqm';
import module namespace conv = 'http://le-tex.de/converter' at 'converter.xqm';
import module namespace config = 'http://le-tex.de/config' at 'config.xqm';
import module namespace hf = 'http://le-tex.de/helper-functions' at 'helper-functions.xqm';
import module namespace i18n = 'http://le-tex.de/i18n' at 'i18n.xqm';
import module namespace st = 'http://le-tex.de/store' at 'store.xqm';
import module namespace queue = 'http://le-tex.de/queue' at 'queue.xqm';
import module namespace u = 'http://le-tex.de/user' at 'user.xqm';

(: 
 : wrapper module for the orchestration of conversion runs.
 :)
declare function make:start-target-run($targetname as xs:string, $converter as element(converter), $target-parameters as map(xs:string,xs:string), $files as map(xs:string, xs:base64Binary), $username as xs:string? := ()) as element(run) {
  let $makefile := make:get-makefile-for-target($converter, $targetname),
      $runid := hf:id(),
      $store := st:set('runid', $runid, $runid),
      $store := st:set('username', $runid, $username),
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
          $ns:store || " declare variable $parameters external; declare variable $options external; proc:execute('make',$parameters,$options), st:set('status', '" || $runid || "', 'stopped'), st:set('end', '" || $runid || "', job:execute('current-dateTime()'))",
          map {'parameters':$parameters,'options':$options},
          map {'cache':true(), 'id':hf:id('make-target')},
          $ns:store || "declare variable $job-id external; st:set('job-id', '" || $runid || "',$job-id), st:set('status', '" || $runid || "','running')"),
      $wait := prof:sleep(1000),
      $store := st:set('queue-id',$runid,$queue-job?id),
      $is-pending := queue:is-pending($queue-job?id),
      $store := if ($is-pending) then st:set('status',$runid, 'pending'),
      $error-message := ()
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

declare function make:stop-run($runid) {
  let $run := (st:get-run($runid),{})[1],
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


declare function make:get-runs() as map(xs:string, map(xs:string,item()*))?{
  map:merge (
    for $runid in st:list()
    return
      map {$runid: st:get-run($runid)}
  )
};

declare function make:get-run($runid as xs:string?) as map(xs:string,item()*)? {
  st:get-run($runid)
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

declare function make:run-info-display($runid as xs:string, $run as map(*), $lang as xs:string, $converter-id as xs:string, $context as map(*)){
  let $filename as xs:string? := $run?filename,
      $start as xs:dateTime := xs:dateTime($run?start),
      $running-text := i18n:static-replacement($run?status,$lang)
  return 
    element div {
      attribute class {'run-info line'},
      element div {
        attribute class {'run-info running'},
        $running-text,
        hf:create-anchor(config:url('/' ||$lang || '/converter/' || $converter-id || '/runs/' || $runid), if ($run?status eq 'running') then i18n:static-replacement("logs",$lang) else i18n:static-replacement("results",$lang))
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
        hf:create-anchor(config:url('/' ||$lang || '/converter/' || $converter-id || '/runs/' || $runid || '/cancel' || '?url=/' || $lang || $context?url), i18n:static-replacement("cancel",$lang))
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