module namespace conv = 'http://le-tex.de/converter';

declare variable $conv:converters := doc("converter.xml")/converters/*;

declare function conv:get-all() as element(converter)*{
  $conv:converters
};

declare function conv:get($converter-id as xs:string) as element(converter){
  $conv:converters[@id eq $converter-id]
};

declare function conv:get-makefile($converter as element(converter)) as xs:string {
  $converter/makefile/xs:string(@location)
};