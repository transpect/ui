module namespace conv = 'http://le-tex.de/converter';

declare variable $conv:converters := doc("/opt/basex/install/transpectui/converter.xml")/converters/converter;

declare function conv:get-all() as element(converter)*{
  $conv:converters
};

declare function conv:get($converter-id as xs:string) as element(converter)?{
  $conv:converters[@id eq $converter-id]
};

declare function conv:get-makefile($converter as element(converter)) as xs:string {
  $converter/makefile/xs:string(@location)
};

declare function conv:get-post-conv-actions($converter as element(converter)) {
  if (exists($converter/webgui-makefile/@location))
  then
    let $lines := tokenize(file:read-text($converter/webgui-makefile/@location),'\n'),
        $actions-start as xs:integer := 
          for $l at $i in $lines
          where matches($l,'^actions:')
          return $i,
        $actions-end as xs:integer := 
          (for $l at $i in $lines
          where $i gt $actions-start and (normalize-space($l) eq '')
          return $i)[1],
        $actions :=
      	for $l at $i in $lines
          let $parts := tokenize($l,'\s')
          where $i gt $actions-start
            and $i lt $actions-end
          return
            element action {
            	attribute target {replace($parts[3],'"','')},
              attribute index {$i},
              attribute message {replace(string-join(for $j in (4 to count($parts)) return $parts[$j],' '),'"','')}
            },
      $add-regexes :=
      	for $action in $actions 
        let $regex-line :=
              let $target-start := 
                for $l at $i in $lines 
                where matches($l, $action/@target || '_regex:')
                return $i
              return $lines[$target-start + 1],
            $normalize-regex := tokenize(normalize-space($regex-line),"'")[2]
        return $action update {insert node attribute regex {$normalize-regex} into .}
    return ($add-regexes)
  else ()
};