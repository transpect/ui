module namespace f = 'http://le-tex.de/floor';
import module namespace config = 'http://le-tex.de/config' at 'config.xqm';

declare variable $f:config := $config:file/configurations/configuration/global-queue;
declare variable $f:global-queue-size := ($f:config/global-queue/xs:string(@size),'5')[1];

declare
  %rest:GET
  %rest:path("/request/{$id}")
  %output:method("xml")
function f:request-frontend($id as xs:string){
  let $space := xs:integer($f:global-queue-size) - xs:integer(f:current-runs()),
      $start := $space gt 1
  return
    if ($start)
    then f:request($id)
    else element allowed {false()}
};

declare
  %rest:GET
  %rest:path("/free/{$runid}")
  %output:method("xml")
function f:free-frontend($runid as xs:string){
  f:free($runid)
};

declare
  %rest:GET
  %rest:path("/list")
  %output:method("xml")
function f:list(){
  serialize(f:runs())
};

declare
  %rest:GET
  %rest:path("/request")
  %output:method("xml")
function f:status(){
  element status {xs:integer($f:global-queue-size) gt xs:integer(f:current-runs())}
};

declare function f:request($id as xs:string) {store:put($id,current-dateTime()),element allowed {true()}};
declare function f:free($runid as xs:string) {store:remove($runid), element freed {true()}}; 
declare function f:current-runs() {count(f:runs())};
declare function f:runs() {element runs {for $k in store:keys() return element run {attribute runid {$k}, attribute timestamp {store:get($k)}}}};