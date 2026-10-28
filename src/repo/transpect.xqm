module namespace tr  = 'http://le-tex.de/transpect';
import module namespace u = 'http://le-tex.de/user' at 'user.xqm';
import module namespace make = 'http://le-tex.de/make' at 'make.xqm';
import module namespace worker = 'http://le-tex.de/worker' at 'worker.xqm';
import module namespace conv = 'http://le-tex.de/converter' at 'converter.xqm';
import module namespace hf = 'http://le-tex.de/helper-functions' at 'helper-functions.xqm';
import module namespace ns = 'http://le-tex.de/namespaces' at 'namespaces.xqm';

declare variable $tr:rights-map :=
  map {
    '^(/[^/]+)?/admin':'admin:admin',
    '^(/[^/]+)?/worker$':'worker:list',
    '^(/[^/]+)?/worker/([^/]+)$':'$2:list',
    '^(/[^/]+)?/worker/([^/]+)/converter$':'$2:list',
    '^(/[^/]+)?/worker/([^/]+)/converter/([^/]+)$':'$2-$3:default',
    '^(/[^/]+)?/worker/([^/]+)/converter/([^/]+)/runs$':'$2-$3:default',
    '^(/[^/]+)?/worker/([^/]+)/converter/([^/]+)/convert$':'$2-$3:convert',
    '^(/[^/]+)?/converter$':'tr:list',
    '^(/[^/]+)?/converter/([^/]+)$':'$2:default',
    '^(/[^/]+)?/converter/([^/]+)/runs$':'$2:default',
    '^(/[^/]+)?/converter/([^/]+)/convert$':'$2:convert',
    '^(/[^/]+)?/users$':'u:mgmt',
    '^(/[^/]+)?/users/([^/]+)$':'u:mgmt',
    '^(/[^/]+)?/users/([^/]+)/delete$':'u:mgmt',
    '^(/[^/]+)?/users/([^/]+)/roles/([^/]+)/add$':'u:mgmt',
    '^(/[^/]+)?/users/([^/]+)/roles/([^/]+)/remove$':'u:mgmt',
    '^(/[^/]+)?/users/([^/]+)/sessions/([^/]+)$':'u:mgmt'
  };
  
declare variable $tr:owner-map :=
  map {
    '^(/[^/]+)?/users/([^/]+)$':'$2'
  };

declare function tr:endpoint-right($url as xs:string?) as xs:string* {
  let $matching :=  
        for $regex in map:keys($tr:rights-map)
        where matches($url, $regex)
        return replace($url,$regex,$tr:rights-map?$regex)
  return $matching
};

declare function tr:endpoint-owner($url as xs:string?) as xs:string* {
  let $matching :=  
        for $regex in map:keys($tr:owner-map)
        where matches($url, $regex)
        return replace($url,$regex,$tr:owner-map?$regex)
  return $matching
};

declare variable $tr:dynamic-worker-roles :=
  for $w in $worker:worker
  let $converters := worker:converter($w)
  return 
    for $c in $converters
    return 
      for $r in (map {'role':'default', 'name': 'convert,default'},map {'role':'runs', 'name': 'conversions,default'},map {'role':'admin', 'matches': ''})
      return
        element role {
          attribute name {$c/@worker || '-' || $c/@id || ':' || $r?role},
          for $name in tokenize($r?name,',') return 
          element right {
            attribute name {$c/@worker || '-' || $c/@id || ':' || $name}[map:keys($r) = 'name']
          }[map:keys($r) = 'name'],
          element right {
            attribute matches {$c/@worker || '-' || $c/@id || ':' || $r?name}
          }[map:keys($r) = 'matches']
        };
        
declare variable $tr:dynamic-local-roles :=
  for $c in $conv:converters
  return
    for $r in (map {'role':'default', 'name': 'convert,default'},map {'role':'runs', 'name': 'conversions'},map {'role':'admin', 'matches': ''})
    return
      element role {
          attribute name {$c/@id || ':' || $r?role},
          for $name in tokenize($r?name,',') return 
          element right {
            attribute name {$c/@id || ':' || $name}
          }[map:keys($r) = 'name'],
          element right {
            attribute matches {$c/@id || ':' || $r?name}
          }[map:keys($r) = 'matches']
        };
        
declare variable $tr:dynamic-roles := ($tr:dynamic-worker-roles, $tr:dynamic-local-roles);

declare function tr:check($username as xs:string?, $token as xs:string?, $right as xs:string?, $owner as xs:string? := ()) {
  let $is-valid := u:validate-token($username, $token),
      $is-allowed := if ($is-valid) then u:check($username, $token, $right, $owner, $tr:dynamic-roles) else false()
  return $is-allowed
};

declare function tr:can-do($username as xs:string?, $right as xs:string?, $owner as xs:string? := ()) {
  u:can-do(u:users($username), $right, $tr:dynamic-roles, $owner)
};

declare function tr:roles() {
  let $static-roles := u:roles()
  return $static-roles update {insert nodes ($tr:dynamic-roles) into .}
};

declare function tr:roles-for-right($right as xs:string?) as xs:string* {
  if (exists($right))
  then
    for $role in ($tr:dynamic-roles,u:roles()/role)
    where (matches($right,$role/right/@matches)[exists($role/right/@matches)] or $role/right/@name[$right eq .])
    return $role/@name
};


declare function tr:get-run($runid as xs:string, $converter as element(converter)? := (), $worker as element(worker)? := ()) as element(run)? {
  if (exists($worker))
  then worker:get-run($converter,$runid)
  else make:get-run($runid)
};

declare function tr:start-run($file as map(xs:string, xs:base64Binary), $text-params as map(*), $converter as element(converter), $username as xs:string, $worker as element(worker)? := ()) {
  if (exists($worker))
  then
    worker:convert($worker, $converter/xs:string(@id), $file, $text-params, $username)
  else
    make:start-target-run('conversion', $converter, $text-params, $file, $username)
};

declare function tr:delete-run($run as element(run), $converter as element(converter), $worker as element(worker)? := ()) {
  hf:log('delete run: ' || $run/runid/text(),'DELRUN'),
  if (exists($worker))
  then
    worker:delete-run($worker, $converter, $run)
  else
    make:delete-run($run) 
};

declare function tr:stop-run($run as element(run), $username as xs:string? := 'admin', $converter as element(converter)? := (), $worker as element(worker)? := ()) {
  if (exists($worker))
  then worker:stop-run($worker, $converter, $run, $username)
  else make:stop-run($run)
};

declare function tr:get-file-logs($run as element(run), $converter as element(converter), $worker as element(worker)? := ()) as element(line)* {
  if (exists($worker))
  then worker:get-file-logs($worker, $converter,$run)
  else make:get-file-logs($run/file)
};

declare function tr:get-result-files($run as element(run), $converter as element(converter), $worker as element(worker)? := ()) as element(file)* {
  if (exists($worker))
  then worker:get-result-files($worker, $converter, $run)
  else make:get-result-files($run)
};

declare function tr:get-file($run as element(run), $filename as xs:string,  $converter as element(converter), $worker as element(worker)? := ()) as xs:base64Binary {
  if (exists($worker))
  then worker:get-file($worker, $converter, $run, $filename)
  else make:get-file($run, $filename)
};

declare function tr:get-job-messages($run as element(run), $converter as element(converter), $worker as element(worker)? := ()) as element(line)* {
  if (exists($worker))
  then worker:get-job-messages($worker, $converter, $run)
  else for $l in make:store-job-messages($run) return element line {$l}
};

declare function tr:get-job-errors($run as element(run), $converter as element(converter), $worker as element(worker)? := ()) as element(line)* {
  if (exists($worker))
  then worker:get-job-errors($worker, $converter, $run)
  else for $l in make:store-job-errors($run) return element line {$l}
};

declare function tr:allowed($converter as element(converter), $caller as xs:string?, $run as element(run)){
  let $converter-id as xs:string? := $converter/@id,
      $worker as xs:string? := $converter/@worker,
      $username := $run/username/text(),
      $same-group := 
        let $my-groups := u:groups($caller),
            $run-groups :=
              if ($username)
              then u:groups($username)
              else (),
            $group-matches := $my-groups[. = $run-groups]
        return count($group-matches) gt 0,
     $owner := $username eq $caller,
     $can-do := tr:can-do($caller,($worker || '-')[$worker] || $converter-id || ':runs') 
  return ($same-group or $owner or  $can-do)
};

declare function tr:get-runs($converter as element(converter)) as element(run)*  {
  admin:write-log('select runs for ' || $converter/@id ,'RUNS'),
  if ($converter instance of xs:string)
  then make:get-local-runs($converter)
  else
    if (exists($converter/@worker))
    then worker:get-runs(worker:get-by-id($converter/@worker))
    else make:get-local-runs($converter)
};

declare function tr:search($filter as element(filter)){
  let $object-type as xs:string:= $filter/@object-type,
      $context := map:merge(
        for $att in $filter/@* except $filter/@object-type
        return map:entry(name($att),xs:string($att))
      ),
      $result :=
        switch($object-type)
        case 'run' return tr:search-run($context) 
        default return ()
  return $result
};

declare function tr:search-run($context as map(*)) {
  let $worker := if ($context?worker-id) then tr:get-worker($context?worker-id) else (),
      $converter := if ($worker) then tr:get-worker-converter($worker,$context?coverter-id) else tr:get-local-converter($context?coverter-id),
      $username := $context?username
  return tr:get-runs($converter, $username, false())      
};

declare function tr:get-runs($converter as element(converter), $username as xs:string, $grouped as xs:boolean? := true()) as element(runs) {
  admin:write-log('select runs for ' || $converter/@id || ', ' || $username ,'RUNS'),
  if ($grouped)
  then
    let $runs as element(run)* := tr:get-runs($converter),
        $allowed-runs := 
          for $run in $runs
          where tr:allowed($converter, $username,$run)
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
          return $run
    return
      element runs {
        element pending {
          $pending-runs
        },element running {
          $running-runs
        },element finished {
          $finished-runs
        }
      }
  else
    let $runs as element(run)* := tr:get-runs($converter),
        $allowed-runs := 
          for $run in $runs
          where tr:allowed($converter, $username,$run)
          return $run
    return 
      element runs {
        $allowed-runs
      }
};

declare function tr:get-worker($worker-id as xs:string? := ()) as element(worker)* {
  if (exists($worker-id))
    then worker:get-by-id($worker-id)
    else $worker:worker
};

declare function tr:get-worker-status($worker as element(worker)) as element(*) {
  worker:get-status($worker)
};

declare function tr:get-worker-converter($worker as element(worker)? := (), $converter-id as xs:string? := ()) as element(converter)* {
  worker:converter($worker,$converter-id)
};

declare function tr:get-local-converter($converter-id as xs:string? := ()) as element(converter)* {
  if (exists($converter-id))
  then conv:get($converter-id)
  else conv:get-all()
};

declare function tr:system-memory() as element(mem){
  let $lines as xs:string* := proc:execute("cat",'/proc/meminfo')?output ! tokenize(.,'\n')
  return 
    element mem {
      for $l in $lines
      let $tokens := tokenize($l,':'),
          $key := normalize-space($tokens[1]),
          $value := normalize-space($tokens[2] => replace('kB',''))
      return element entry {
        attribute key {$key},
        attribute value {if (matches($value,'^\d+$')) then xs:integer($value) else $value}
        
      } 
    }
};

declare function tr:schedule-cpu() {
  let $info := tokenize(proc:execute('mpstat',('-P', 'ALL','1','3'))/output,'\n')[matches(.,'^\d')],
      $count := count($info),
      $max-index := round($count div 3),
      $names := tokenize($info[1],' ')[normalize-space(.)],
      $store :=
        store:put(
          'current-cpu',
          element cpu {
            for $line in $info[position() ne 1][position() lt $max-index]
              let $token := tokenize($line,' ')[normalize-space(.)]
              return 
              	element {'cpu' || $token[3]} {
               	 for $name at $index in $names
               	 where $index = (3 to 13)
                  return
                    element entry {
                      attribute key {$name},
                      attribute value {$token[$index]}
                    }
                }
          }),
      $job-ids := ('cpu-schedule0','cpu-schedule1'),
      $running-jobs := job:list()[. = $job-ids],
      $rerun := for $id in $job-ids where not($running-jobs = $id) return hf:eval($ns:tr,"tr:schedule-cpu()",{},map {'id':$id}) 
  return $store
};

declare function tr:system-cpu() as element(cpu){
  let $job-ids := ('cpu-schedule0','cpu-schedule1'),
	    $job-running as xs:boolean := job:list() = $job-ids,
	    $data := store:get('current-cpu'),
	    $start-job :=  if ($job-running)then () else hf:eval($ns:tr,"tr:schedule-cpu()",{},map {'id':'cpu-schedule0'}) 
return if (exists($data)) then $data else element cpu {}
};