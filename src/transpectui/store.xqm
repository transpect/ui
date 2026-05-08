module namespace st = 'http://le-tex.de/store';

(: 
 : wrapper module for basex store access
 :)

declare function st:set($prefix, $runid, $value){
  store:put($prefix || ':' || $runid, $value)
};

declare function st:get($prefix, $runid){
  store:get($prefix || ':' || $runid)
};