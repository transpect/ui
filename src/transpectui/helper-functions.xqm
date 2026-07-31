module namespace hf = 'http://le-tex.de/helper-functions';
import module namespace ns = 'http://le-tex.de/namespaces' at 'namespaces.xqm';
import module namespace i18n = 'http://le-tex.de/i18n' at 'i18n.xqm';

(: 
 : helper functions without any dependencies outside of the namespace list.
 :)

declare variable $hf:log-eval := true();

declare function hf:eval($namespaces as xs:string*, $query as xs:string, $variables as map(*)?, $options as map(*)?, $emit-options as map(*)* := ()) {
  let $declaration :=
        for $k in $variables ! map:keys(.)
        where not(contains($query,'declare variable $' || $k ||' external;'))
        return 'declare variable $' || $k ||' external;',
      $log := if ($hf:log-eval) then admin:write-log($query,'EVAL') else (),
      $call := string-join(($namespaces, $declaration, $query),'&#13;'),
      $job-id := job:eval($call, $variables, $options),
      $start-emit := hf:emit-updates($job-id, $emit-options)
  return $job-id
};

declare function hf:emit-updates($job-id, $emit-options) {
  let $update-types := distinct-values($emit-options ! .?update) (: 'update','add','delete' :)
  return
    for $emit-update-type in $update-types
    let $emit-options-sub := $emit-options[.?update eq $emit-update-type]
    return 
      for $type in distinct-values($emit-options-sub ! .?type)
      return 
        hf:emit-update-multi($job-id, $emit-options-sub[.?type eq $type],$emit-update-type, $type)
};

declare function hf:emit-update-multi($job-id, $emit-options, $emit-update-type, $objects-type){
  if (count($emit-options) gt 0)
  then
    if (count($emit-options) eq 1)
    then 
      hf:emit-update($job-id,$emit-options[1])
    else
      let $objects := (for $o in $emit-options return map {'type':$o?type, 'object-id':$o?object-id})
      return
        hf:eval-after-jobs(
          $job-id,
          (:$ns:data:)(),
          switch ($emit-update-type){
            case 'update' return 'data:cache-clear((),$type), data:updates($objects)'
            case 'delete' return 'data:cache-clear((),$type), data:deletes($objects)'
            case 'add' return 'data:cache-clear((),$type), data:adds($objects)'
            default return ()},
          map {'type':$objects-type, 'objects':$objects},
          map {'id':hf:id($emit-update-type), 'cache':false()}, (), 'PT1S'
        )
};

declare function hf:emit-update($job-id,$emit-options){
  let $start := 
    if ($emit-options?update)
    then
      hf:eval-after-jobs(
        $job-id,
        (:$ns:data:)(),
        switch ($emit-options?update){
          case 'update' return 'data:cache-clear((), $type), data:update($type, $object-id)'
          case 'delete' return 'data:cache-clear((), $type), data:delete($type, $object-id)'
          case 'add' return 'data:cache-clear((), $type), data:add($type, $object-id)'
          default return ()},
        map {'type':$emit-options?type, 'object-id':$emit-options?object-id},
        map {'id':hf:id($emit-options?update), 'cache':false()}, (), 'PT1S'
      )
    else()
  return ()
};

declare function hf:eval-after-jobs($job-ids as xs:string*, $namespaces as xs:string*,
                                    $query as xs:string, $variables as map(*),
                                    $job-options as map(*)?, $log-message as xs:string? := (),
                                    $timeout as xs:string? := 'PT5S', $emit-options as map(*)* := ()) {
  let $distinct as xs:string* := distinct-values($job-ids),
      $job-id-regexes as xs:string* := $distinct[matches(., '[?.*+\(\)\[\]\{\}\^\$]')],
      $plain-job-ids as xs:string* := $distinct[not(. = $job-id-regexes)],
      $matching-jobs as xs:string* := ($plain-job-ids, for $jr in $job-id-regexes return job:list()[matches(., $jr)])
                                         [job:list-details(.)[not(@state = ('cached', 'stopped'))]]
  return 
    if (empty($matching-jobs))
    then let $job-id := hf:eval($namespaces, 'let $msg := admin:write-log($log-message) return '[$log-message] || $query, 
                                  map:merge(($variables, map{'log-message': $log-message})), $job-options, $emit-options)
         return ($job-id, if ($log-message) then hf:log('hf:eval-after-jobs(): ' || $job-id || ' executing ' || $log-message))
    else let $schedule-id := string-join(('schedule', $job-options?id, random:uuid()  ! tokenize(.,'-')[1]), '_')(:,
             $msg := hf:log($schedule-id || ' waiting for ' || string-join(($job-id-regexes, $matching-jobs), ', ') || ': '[$log-message] || $log-message):)
         return hf:eval($ns:hf, 'hf:eval-after-jobs($job-ids, $namespaces, $query, $variables, $job-options, $log-message, $timeout, $emit-options)',
                          map {'job-ids': ($matching-jobs, $job-id-regexes), 'namespaces': $namespaces, 'query': $query, 'variables': $variables,
                               'job-options': $job-options, 'log-message': $log-message, 'timeout':$timeout, 'emit-options':$emit-options},
                          map {'id': $schedule-id, 'start': $timeout, 'cache': (false(), $job-options?cache)[1] }
                         )
};

declare function hf:build-emit-options($update as xs:string?, $type as xs:string?, $object-id as xs:string?){
  map{'update':$update,'type':$type,'object-id':$object-id}
};

declare function hf:id($prefix as xs:string? := (), $suffix as xs:string? := (), $length as xs:integer? := 5){
  ($prefix || '_')[$prefix] || (random:uuid() ! replace(.,'-','') ! substring(.,1,$length)) || ('_' || $suffix)[$suffix]
};

declare function hf:log($message,$type as xs:string := 'TRACK',$toggle as xs:boolean := true()) as empty-sequence(){
  let $is-string := $message castable as xs:string
  return
    if ($toggle)
    then admin:write-log(
      if ($is-string)
      then xs:string($message)
      else if (exists($message))
           then $message
           else 'EMPTY',$type)
    else ()
};

declare function hf:ml-log($messages, $position as xs:string := 'start', $type as xs:string := 'TRACK',$toggle as xs:boolean := true()) as empty-sequence(){
  let $type-length := string-length($type) 
  return 
    switch ($position) {
      case 'start' return
        (
          hf:log($messages[1],'└' || $type),
          for $m at $i in $messages
          where $i ge 2
          return 
            hf:log($messages[$i],'┃')
        )
      case 'middle' return
        (
          for $m at $i in $messages
          return 
            hf:log($messages[$i],'┃')
        )
      
      case 'end' return
        (
          for $m at $i in $messages
          where $i lt count($messages)
          return 
            hf:log($messages[$i],'┃'),
          hf:log($messages[count($messages)],'┌' || $type)
        )
      default return hf:log('ERROR: $position is not valid.')
    }
};

declare function hf:element-to-document($item, $base-uri as xs:string){
  parse-xml(serialize($item), map {'base-uri':$base-uri})
};

declare function hf:map-to-list($map as map(*)){
  for $key in map:keys($map)
  return $map?$key
};

declare function hf:create-anchor($href,$text as xs:string? := (), $classes as xs:string* := ()) {
  element a {
    if ($classes) then attribute class {string-join($classes, ' ')} else (),
    attribute href {$href},
    attribute title {$text}, 
    $text
  }
};

declare function hf:format-dateTime($dateTime as xs:dateTime) as xs:string {
  format-dateTime($dateTime,'[D,2].[M,2].[Y,4] [H,2]:[m,2]:[s,2]')
};

declare function hf:format-duration($duration as xs:dayTimeDuration) as xs:string {
  let $days := days-from-duration($duration),
      $hours := hours-from-duration($duration),
      $minutes := minutes-from-duration($duration),
      $seconds := seconds-from-duration($duration)
  return
    ($days || 'd ')[$days gt 0] ||
    string-join((
      $hours[$hours gt 0 or $days gt 0],
      format-integer($minutes,"00"),
      format-number($seconds,"00.0")
    ),':')
};

declare function hf:inspect-namespaces(){
  let $base-uri := '/opt/basex/webapp/transpectui/',
      $files := file:list($base-uri)[matches(.,'\.xqm')],
      $first :=
        element nss {
          for $file in $files
          let $xqdoc := inspect:xqdoc($base-uri || $file),
              $uri := $xqdoc/*:module/*:uri/text() ! tokenize(.,'/')[last()],
              $imports := $xqdoc/*:imports/*:import/*:uri/text() ! tokenize(.,'/')[last()]
          return
            element ns {
              attribute name {$uri},
              attribute file {$base-uri || $file},
              for $import in $imports
              return
                element import {
                  attribute name {$import}
                }
            }
        },
      $second :=
        $first update {
          for $ns in ns
          let $exports := $first//import[@name eq $ns/@name]
          return
            for $export in $exports 
            let $parent := $export/parent::*
            return
              insert node element export {$parent/@name} into $ns
        }
  return $second
    
};

declare function hf:build-namespace-tree(
                    $inspected as element(nss),
                    $current-ns as xs:string? := (),
                    $used-namespaces as xs:string* := ()){
  let $current-ns :=
        $current-ns
          otherwise (
            for $ns in $inspected/ns
            order by count($ns/import) - count($ns/export) descending
            return $ns
          )[1]/xs:string(@name),
      $is-already-used := exists($used-namespaces[. eq $current-ns]),
      $upd-used-namespaces := ($used-namespaces, $current-ns),
      $namespace-to-use := $inspected/ns[@name eq $current-ns],
      $imports := $namespace-to-use/import/@name,
      $exports := $inspected//import[@name eq $current-ns]
  return
    if ($is-already-used)
    then
      element LOOP {
        attribute to {$namespace-to-use/@name}
      }
    else
      element ns {
        attribute uri {$current-ns},
        attribute imports {count($imports)},
        attribute imported-by {count($exports)},
        for $import in $imports
        return hf:build-namespace-tree($inspected,$import, $upd-used-namespaces)
      }
};

declare function hf:parameter-to-html($input as element(*), $lang as xs:string){
  let $id := ($input/xs:string(@p-name),hf:id())[1],
      $name := i18n:name($input, $lang)
  return
    element form-group{
      element label {$name || ':'},
      switch (local-name($input))
        case "input"
        return 
          $input update {
            delete node @name,
            insert node attribute placeholder {$name} into .,
            insert node attribute name {$id} into .,
            insert node attribute id {$id} into .,
            insert node attribute class {'form-control'} into .
          }
        case "radiogroup"
        return
          for $radio at $index in $input/input[@type = 'radio']
          let $sub-id := hf:id()
          return
            element div{
              $radio update {
                delete node @name,
                insert node attribute name {$id} into .,
                insert node attribute id {$sub-id} into .,
                if ($index eq 1) then insert node attribute checked {} into .},
              element label {
                attribute "for" {$sub-id},
                $radio/xs:string(@name)
              }
           }
        case "select"
        return
          $input update {
            insert node attribute id {$id} into .,
            insert node attribute class {'form-control'} into .}
        default return ()
    }
};