module namespace st = 'http://le-tex.de/store';

declare variable $st:cache-key := 'st:cache';
declare variable $st:cache-age-key := $st:cache-key || '_timestamp';
declare variable $st:cache-max-age := xs:dayTimeDuration('PT1H0M0S');
(: 
 : wrapper module for basex store access
 :)

declare function st:set($prefix, $runid, $value){
  if (store:keys() = $st:cache-key)
  then st:set-in-cache($prefix, $runid, $value)
  else (),
  
  if (not(file:exists("/opt/data/runs/" || $runid))) then file:create-dir("/opt/data/runs/" || $runid) else (),
  
  if ($value instance of element()) 
  then file:write("/opt/data/runs/" || $runid || '/' || $prefix,$value)
  else file:write-text-lines("/opt/data/runs/" || $runid || '/' || $prefix, $value ! xs:string(.))
};

declare function st:get($prefix, $runid){
  if (store:keys() = $st:cache-key)
  then st:get-from-cache($prefix, $runid)
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

declare function st:list($use-cache as xs:boolean? := true()) as xs:string* {
  if ($use-cache)
  then for $run in store:get($st:cache-key) return $run?runid
  else 
    let $runids := file:list("/opt/data/runs") ! tokenize(.,'/')[1]
    return
      for $runid in $runids
      let $file := st:get('file',$runid),
          $file-exists := if ($file) then file:exists($file)
      where $file-exists 
      return $runid
};

declare function st:get-run($runid as xs:string) as map(xs:string, item()*)?{
  map:build(
    file:list('/opt/data/runs/' || $runid),
    keys := fn { . },
    value := fn { st:get(.,$runid) }
  )
};

(: store cache :)

declare function st:rebuild-cache(){
  store:put($st:cache-age-key,current-dateTime()),
  let $runs :=
        for $runid in st:list(false())
        return st:get-run($runid)
  return store:put($st:cache-key,$runs)
};

declare function st:check-cache-age(){
  if (current-dateTime() - store:get($st:cache-age-key) ge $st:cache-max-age)
  then (admin:write-log('Store Cache is too old.','CACHE-AGE'),
        st:rebuild-cache()
        )
};

declare function st:set-in-cache($prefix, $runid, $value) {
  let $all := store:get($st:cache-key),
      $rest := $all[not(.?runid eq $runid)],
      $prev := $all[.?runid eq $runid],
      $new := map:put($prev,$prefix,$value)
  return store:put($st:cache-key, ($all,$new))
};

declare function st:get-from-cache($prefix, $runid) {
  store:get($st:cache-key)[.?runid eq $runid]?$prefix
};
