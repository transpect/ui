module namespace st = 'http://le-tex.de/store';

import module namespace hf = 'http://le-tex.de/helper-functions' at '/opt/basex/webapp/transpectui/helper-functions.xqm';

declare variable $st:cache-key := 'st:cache';
declare variable $st:cache-age-key := $st:cache-key || '_timestamp';
declare variable $st:cache-max-age := xs:dayTimeDuration('PT1H0M0S');
(: 
 : wrapper module for basex store access
 :)
 
declare function st:set($prefix, $runid, $value){
  if (store:keys() = $st:cache-key)
  then st:set-in-cache($prefix, $runid, $value)
  else (st:rebuild-cache(), st:set-in-cache($prefix, $runid, $value)),
  
  if (not(file:exists("/opt/data/runs/"))) then file:create-dir("/opt/data/runs/") else (),
  if (not(file:exists("/opt/data/runs/" || $runid))) then file:create-dir("/opt/data/runs/" || $runid) else (),
  
  if ($value instance of element()) 
  then file:write("/opt/data/runs/" || $runid || '/' || $prefix,$value)
  else file:write-text-lines("/opt/data/runs/" || $runid || '/' || $prefix, $value ! xs:string(.))
};

declare function st:get($prefix, $runid){
  if (store:keys() = $st:cache-key)
  then (st:check-cache-age(), st:get-from-cache($prefix, $runid))
  else
    let $file := "/opt/data/runs/" || $runid || '/' || $prefix
    return
      let $text := if (file:exists($file)) then file:read-text($file) else (),
          $parse := 
            try {
              parse-xml($text)
            } catch * {
              $text ! tokenize(.,'\n')[normalize-space(.)]
            }
      return $parse
};

declare function st:delete($runid) {
  if (store:keys() = $st:cache-key)
  then st:delete-from-cache($runid)
  else (st:rebuild-cache(), st:delete-from-cache($runid)),
  
  if (file:exists("/opt/data/runs/" || $runid)) then file:delete("/opt/data/runs/" || $runid, true()) else ()
};

declare function st:list($use-cache as xs:boolean? := true()) as xs:string* {
  if ($use-cache)
  then
    if (store:keys() = $st:cache-key)
    then for $run in store:get($st:cache-key) return $run?runid
    else st:rebuild-cache()
  else 
    let $runids := if (file:exists("/opt/data/runs")) then file:list("/opt/data/runs") ! tokenize(.,'/')[1] else ()
    return
      for $runid in $runids
      let $file := st:get('file',$runid),
          $file-exists := if ($file) then file:exists($file)
      where $file-exists 
      return $runid
};

declare function st:get-run($runid as xs:string) as element(run)?{
  element run {
      hf:map-to-xml(st:get-run-map($runid))
  }
};
declare function st:get-run-map($runid as xs:string) as map(xs:string, item()*){
  let $path := '/opt/data/runs/' || $runid,
      $exists := file:exists($path)
  return
      if ($exists)
      then
        map:build(
          file:list($path),
          key := fn { . },
          value := fn { st:get(.,$runid) }
        )
      else map {}
};

(: store cache :)

declare function st:rebuild-cache(){
  store:put($st:cache-age-key,current-dateTime()),
  let $runs :=
        for $runid in st:list(false())
        return st:get-run-map($runid),
      $store := store:put($st:cache-key,$runs)
  return st:list(false())
};

declare %private function st:check-cache-age(){
  if (current-dateTime() - store:get($st:cache-age-key) ge $st:cache-max-age)
  then (admin:write-log('Store Cache is too old.','CACHE-AGE'),
        st:rebuild-cache()
        )
};

declare %private function st:set-in-cache($prefix as xs:string, $runid as xs:string, $value as item()*) {
  let $all as map(*)* :=  store:get($st:cache-key),
      $rest as map(*)* := $all[not(.?runid eq $runid)],
      $prev as map(*)? := $all[.?runid eq $runid],
      $new := if (exists($prev)) then map:put($prev,$prefix,$value) else map {$prefix: $value}
  return store:put($st:cache-key, ($rest,$new))
};

declare %private function st:delete-from-cache($runid as xs:string) {
  let $all as map(*)* :=  store:get($st:cache-key),
      $rest as map(*)* := $all[not(.?runid eq $runid)]
  return store:put($st:cache-key, ($rest))
};

declare %private function st:get-from-cache($prefix, $runid) {
  store:get($st:cache-key)[.?runid eq $runid]?$prefix
};
