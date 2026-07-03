module namespace queue = 'http://le-tex.de/queue';

import module namespace ns = 'http://le-tex.de/namespaces' at 'namespaces.xqm';
import module namespace config = 'http://le-tex.de/config' at 'config.xqm';
(: 
 : queue for simultaniously running calls.
 :)
 
declare variable $queue:key := "waiting-queue";
declare variable $queue:running-key := "running-queue";
declare variable $queue:max := 3;

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

declare %private function queue:log($text) {
  admin:write-log($text,'QUEUER')
};

declare function queue:is-queued($id) {
  for $job in array:items(queue:list())
  where $id eq $job?id
  return true()
};

declare %private function queue:add($job-map as map(*)) {
  if (exists(store:get($queue:key)))
  then 
    store:put($queue:key,array:append(store:get($queue:key),$job-map))
  else
    store:put($queue:key,array:build($job-map))
};

declare %private function queue:start-job($job as map(*)) {
  let $job-id := job:eval($job?query, $job?parameter, $job?options),
      $log := queue:log('Start Job ' || $job?id || ' as ' || $job-id),
      $add-to-running := queue:add-to-running($job-id),
      $run-callback := job:eval($job?callback, map{'job-id': $job-id})
  return $job-id
};

declare %private function queue:add-to-running($job-id) {
  store:put($queue:running-key, (store:get($queue:running-key), $job-id))
};

declare %private function queue:get-running() {
  let $registered := store:get($queue:running-key),
      $running := job:list(),
      $matching :=
        for $id in $running
        where job:list-details($id)/@state = ('running','queued')
        where $id = $registered
        return $id
  return $matching
};

(: Loops all the time:)
declare function queue:run() {
  if (not(queue:is-full()))
  then
    let $job-map as map(*)? := queue:pop()
    return if (exists($job-map)) then queue:start-job($job-map)
  else (),
  
  if (not(job:list() = 'queuer1'))
  then job:eval($ns:queue || "queue:run()", {}, map {'id':'queuer1', 'start': 'PT1S'})
  else (),
    
  if (not(job:list() = 'queuer'))
  then job:eval($ns:queue || "queue:run()", {}, map {'id':'queuer', 'start': 'PT1S'})
  else ()
    
};

declare %private function queue:pop() {
  let $list := queue:list(),
      $save := store:put($queue:key,array:tail($list))
  return 
    array:head($list)
};

declare function queue:list() {
  if (exists(store:get($queue:key)))
  then store:get($queue:key)
  else []
};

declare %private function queue:size() as xs:integer {
  count(queue:get-running())
};

declare %private function queue:is-full() as xs:boolean {
  queue:size() ge $queue:max
};

(: Remove all jobs :)
declare %private function queue:clear() {
  store:put($queue:key,[])
};