module namespace queue = 'http://le-tex.de/queue';

import module namespace ns = 'http://le-tex.de/namespaces' at 'namespaces.xqm';
import module namespace config = 'http://le-tex.de/config' at 'config.xqm';
import module namespace hf = 'http://le-tex.de/helper-functions' at 'helper-functions.xqm';
(: 
 : queue for simultaniously running calls.
 :)
 
declare variable $queue:key := "waiting-queue"; (: array of job-definitions :)
declare variable $queue:running-key := "running-queue";
declare variable $queue:max as xs:integer := ($config:file/configurations/configuration/queue/xs:integer(@max),3)[1];
declare variable $queue:gobal-url as xs:string? := $config:file/configurations/configuration/floormanager/base-url;

declare function queue:register($job-query as xs:string, $job-parameter as map(*)? := {}, $job-options as map(*)? := {}, $start-callback := (), $end-callback := ()) {
  let $job-map := map {
        'query': $job-query,
        'parameter': $job-parameter,
        'options': $job-options,
        'queue-id':random:uuid()
      },
      $insert-start-callback := if ($start-callback) then map:put($job-map,'start-callback',$start-callback) else $job-map,
      $insert-end-callback := if ($end-callback) then map:put($insert-start-callback,'end-callback',$end-callback) else $insert-start-callback,
      $add-to-queue := queue:add($insert-end-callback),
      $log := queue:log('Register job ' || $insert-end-callback?queue-id),
      $run := queue:run()
  return $insert-end-callback
};

declare function queue:is-pending($id) {
  for $job in array:items(queue:list())
  where $id eq $job?queue-id
  return true()
};

declare function queue:list() as array(map(*)) {
  if (exists(store:get($queue:key)))
  then store:get($queue:key)
  else []
};

declare function queue:remove($queue-id) as xs:boolean {
  let $queue := store:get($queue:key),
      $removed := array:filter($queue, fn($entry) {$entry?queue-id ne $queue-id}),
      $set := store:put($queue:key,$removed)
  return count(array:filter(store:get($queue:key), fn($entry) {$entry?queue-id eq $queue-id})) eq 0
};

(: Loops all the time:)
declare function queue:run() {
  let $jobs := job:list(),
      $full as xs:boolean := queue:is-full()
  return (
    if (array:size(queue:list()) gt 0)
    then
      if (not($full))
      then
        if (queue:global-queue-check())
        then
          let $job-map as map(*)? := queue:pop()
          return if (exists($job-map)) then queue:start-job($job-map)
        else ()
      else ()
    else (),
    
    for $queue-job in queue:registered()
    let $queue-id := $queue-job?queue-id,
        $timestamp := $queue-job?start
    where current-dateTime() - $timestamp gt xs:dayTimeDuration('PT10S')
    return queue:check-job($queue-id),
    
    if ($jobs = 'check-queue')
    then ()
    else job:eval($ns:queue || ' queue:check()', {}, {'id': 'check-queue'}),
    
    queue:rerun($jobs)
  )
};

declare %private function queue:rerun($jobs as xs:string*){
  if (not($jobs = ('queuer-0','queuer-1'))) (:neither:)
    then job:eval($ns:queue || " queue:run()", {}, map {'id':'queuer-0', 'start': 'PT1S'})
    else 
      for $id in ('queuer-0','queuer-1')
      return
        if (not($jobs = $id))
        then job:eval($ns:queue || " queue:run()", {}, map {'id':$id, 'start': 'PT1S'})
        else ()
}; 

declare %private function queue:log($text) {
  hf:log($text,'QUEUER')
};

declare %private function queue:start-job($job as map(*)) as xs:string? {
  let $job-id :=$job?queue-id,
      $store := store:put('job',$job),
      $compose-query := $job?query || hf:static-replace-variables(", job:eval($callback, {'job-id': $job-id},{'id':$id})",map {'callback':$job?end-callback, 'job-id':$job-id,'id':'end-callback of ' || $job-id},'"')[$job?end-callback],
      $log := queue:log($compose-query),
      $start := job:eval($compose-query, $job?parameter, map {'id':$job-id, 'cache':true()}),
      $log := queue:log('Start Job ' || $job?queue-id || ' as ' || $job-id),
      $add-to-running := queue:add-to-running($job-id),
      $request-global := queue:floormanager-request($job-id),
      $run-callback := job:eval($job?start-callback, map{'job-id': $job-id}, map {'id': 'start-callback of ' || $job-id})
  return $start
};


declare %private function queue:check-job($queue-id as xs:string?) {
  if (not(job:list() = $queue-id))
  then (
    queue:remove-from-running($queue-id)
  )
};

declare %private function queue:add-to-running($queue-id) {
  queue:log('mark as running: ' || $queue-id),
  store:put($queue:running-key, (store:get($queue:running-key), map {'queue-id':$queue-id,'start':current-dateTime()}))
};

declare %private function queue:remove-from-running($queue-id) {
  queue:log('mark as done: ' || $queue-id),
  store:put($queue:running-key, (queue:registered()[not(.?queue-id eq $queue-id)])),
  queue:floormanager-free($queue-id)
};

declare %private function queue:get-running() {
  let $registered := queue:registered(),
      $running-jobs := job:list(),
      $matching :=
        for $job-id in $running-jobs
        where job:list-details($job-id)/@state = ('running','pending')
        where exists($registered[.?job-id eq $job-id])
        return $job-id
  return $matching
};

declare %private function queue:registered() as map(*)* {
  store:get($queue:running-key)
}; 

declare %private function queue:add($job-map as map(*)) {
  if (exists(store:get($queue:key)))
  then 
    store:put($queue:key,array:append(store:get($queue:key),$job-map))
  else
    store:put($queue:key,array:build($job-map))(:,
  queue:floormanager-add($job-map):)
};

(: Remove all jobs :)
declare %private function queue:clear() {
  store:put($queue:key,[])
};

declare %private function queue:pop() {
  let $list := queue:list(),
      $save := if (array:size($list) gt 0) then store:put($queue:key,array:tail($list)) else ()
  return 
    if (array:size($list) gt 0) then array:head($list) else ()
};

declare %private function queue:size() as xs:integer {
  count(queue:get-running())
};

declare %private function queue:is-full() as xs:boolean {
  queue:size() ge $queue:max
};

declare function queue:global-queue-check() as xs:boolean{
  queue:floormanager-call-txt('request',true())
};

declare function queue:floormanager-request($id as xs:string) as xs:boolean {
  queue:floormanager-call-txt('request/' || $id, true())
};

declare function queue:floormanager-free($id as xs:string) as xs:boolean {
  queue:floormanager-call-txt('free/' || $id, true())
};

declare function queue:floormanager-add($job-map as map(*)){
  queue:floormanager-call-txt('register/' || $job-map?queue-id, true())
};

declare function queue:floormanager-call-base($path, $header := (), $body as item()* := (), $method as xs:string := 'get', $override-media-type as xs:string? := ()) {
  let $result := 
        http:send-request(
          element http:request {
            attribute method {$method},
            (attribute override-media-type {$override-media-type})[$override-media-type],
            $header
          },
          $queue:gobal-url || '/' || $path,
          $body
        ),
      $store := store:put('get',$result),
      $error-handled := if ($result instance of xs:string) then hf:log($result,'ERROR') else $result
  return $error-handled
};

declare function queue:floormanager-call-txt($path, $default-value) {
  let $call := if (exists($queue:gobal-url)) then queue:floormanager-call-base($path)[2]/*/text() else $default-value
  return $call
};