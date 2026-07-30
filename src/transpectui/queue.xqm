module namespace queue = 'http://le-tex.de/queue';

import module namespace ns = 'http://le-tex.de/namespaces' at 'namespaces.xqm';
import module namespace config = 'http://le-tex.de/config' at 'config.xqm';
(: 
 : queue for simultaniously running calls.
 :)
 
declare variable $queue:key := "waiting-queue";
declare variable $queue:running-key := "running-queue";
declare variable $queue:max := 3;
declare variable $queue:max-age := 0;

declare function queue:register($job-query as xs:string, $job-parameter as map(*)? := {}, $job-options as map(*)? := {}, $callback := ()) {
  let $job-map := map {
        'query': $job-query,
        'parameter': $job-parameter,
        'options': $job-options,
        'callback': $callback,
        'id':random:uuid()
      },
      $add-to-queue := queue:add($job-map),
      $log := queue:log('Register job ' || $job-map?id),
      $run := queue:run()
  return $job-map
};

declare function queue:is-pending($id) {
  for $job in array:items(queue:list())
  where $id eq $job?id
  return true()
};

declare function queue:list() {
  if (exists(store:get($queue:key)))
  then store:get($queue:key)
  else []
};

declare function queue:remove($id) {
  let $queue := store:get($queue:key),
      $removed := array:filter($queue, fn($entry) {$entry?id ne $id}),
      $set := store:put($queue:key,$removed)
  return count(array:filter(store:get($queue:key), fn($entry) {$entry?id eq $id})) eq 0
};

(: Loops all the time:)
declare function queue:run() {
  let $jobs := job:list(),
      $full as xs:boolean := queue:is-full()
  return (
    if (not($full))
    then
      let $job-map as map(*)? := queue:pop()
      return if (exists($job-map)) then queue:start-job($job-map)
    else (),
    
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
  admin:write-log($text,'QUEUER')
};

declare %private function queue:start-job($job as map(*)) {
  let $job-id := job:eval($job?query, $job?parameter, $job?options),
      $log := queue:log('Start Job ' || $job?id || ' as ' || $job-id),
      $add-to-running := queue:add-to-running($job-id),
      $run-callback := job:eval($job?callback, map{'job-id': $job-id}, map {'id': 'callback to ' || $job-id})
  return $job-id
};

declare %private function queue:queue-check() {
  
};

declare %private function queue:check-job($job-id) {
  if (not(job:list() = $job-id))
  then queue:remove-from-running($job-id)
};

declare %private function queue:add-to-running($job-id) {
  store:put($queue:running-key, (store:get($queue:running-key), map {'id':$job-id,'start':current-dateTime()}))
};

declare %private function queue:remove-from-running($job-id) {
  store:put($queue:running-key, (store:get($queue:running-key)[not(.?id eq $job-id)]))
};

declare %private function queue:get-running() {
  let $registered := store:get($queue:running-key),
      $running := job:list(),
      $matching :=
        for $id in $running
        where job:list-details($id)/@state = ('running','pending')
        where exists($registered[.?id eq id])
        return $id
  return $matching
};

declare %private function queue:add($job-map as map(*)) {
  if (exists(store:get($queue:key)))
  then 
    store:put($queue:key,array:append(store:get($queue:key),$job-map))
  else
    store:put($queue:key,array:build($job-map))
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