module namespace tr = 'http://le-tex.de/transpectui';
import module namespace conv = 'http://le-tex.de/converter' at 'converter.xqm';
import module namespace config = 'http://le-tex.de/config' at 'config.xqm';
import module namespace hf = 'http://le-tex.de/helper-functions' at 'helper-functions.xqm';
import module namespace ns = 'http://le-tex.de/namespaces' at 'namespaces.xqm';
import module namespace i18n = 'http://le-tex.de/i18n' at 'i18n.xqm';
import module namespace make = 'http://le-tex.de/make' at 'make.xqm';

(: 
 : module for all functions to deliver HTML to users
 :)

declare
  %rest:GET
  %rest:path("/{$lang}/login")
  %output:method("html")
  %output:html-version('5')
function tr:login($lang as xs:string := 'de'){
  let $title := 'TranspectUI Login',
      $user := user:current(),
      $url := '/login',
      $context := map {'title': $title, 'lang': $lang, 'url':$url}
  return
    element html {
      config:get-html-head($context),
      element body {
        config:get-html-header($context),
        element div {
          attribute class {'well'},
          element form {
            tr:parameter-to-html(<input type="text" name-de="Username" name-en="Username" p-name="username" required=""/>,$lang),
            tr:parameter-to-html(<input type="password" name-de="Passwort" name-en="Password" p-name="password" required=""/>,$lang),
            element form-group{
              element label {},
              element button {
                  attribute id {'submit-login'},
                  attribute class {'primary-btn'},
                  attribute type {'submit'},
                  i18n:val("login",$lang)
              }
            }
          }
        }
      }
    }
};

declare
  %rest:GET
  %rest:path("/{$lang}/converter")
  %output:method("html")
  %output:html-version('5')
function tr:converter-list($lang as xs:string := 'de'){
  let $title := 'TranspectUI',
      $header := request:header-map(),
      $converters as element(converter)* := conv:get-all(),
      $url := '/converter',
      $context := map {'title': $title, 'lang': $lang, 'url':$url}
  return
    if (count($converters) eq 1)
    then
      web:redirect('/' || $lang || '/converter/' || $converters[1]/xs:string(@id))
    else
      element html {
        config:get-html-head($context),
        element body {
          config:get-html-header($context),
          element div {
            attribute class {'well'},
            for $converter in $converters
            return
              element a {
                attribute class {'block'},
                attribute href {'/' || $lang || '/converter/' || $converter/xs:string(@id)},
                $converter/xs:string(@name)
              }
            
          }
        }
      }
};

declare
  %rest:POST
  %rest:path("/{$lang}/converter/{$converter-id}/convert")
  %rest:form-param('upload_file_uploaded_data', '{ $file }')
  %output:method("html")
  %output:html-version('5')
function tr:run-converter($converter-id as xs:string, $file as map(xs:string, xs:base64Binary), $lang as xs:string){
  let $params := request:parameter-map(),
      $text-params := map:remove(request:parameter-map(),'upload_file_uploaded_data'),
      $converter as element(converter) := conv:get($converter-id),
      $run as element(run) := make:start-target-run('conversion', $converter, $text-params, $file) 
  return if ($run/error)
         then web:redirect('/' || $lang ||'/converter/' || $converter-id || '/error/' || $run/error) 
         else web:redirect('/' || $lang ||'/converter/' || $converter-id || '/log/'   || $run/id)
};

declare 
  %rest:GET
  %rest:path("/{$lang}/converter/{$converter-id}/error/{$error-message}")
  %output:method("html")
  %output:html-version('5')
function tr:error($error-message, $converter-id, $lang) {
  let $converter := conv:get($converter-id),
      $title := $converter/xs:string(@name),
      $url := '/converter/' || $converter-id,
      $context := map {'title': $title, 'lang': $lang, 'url':$url}
  return
    element html {
        config:get-html-head($context),
        element body {
          config:get-html-header($context),
          element div {
            attribute class {'error well'},
            $error-message
          }
        }
      }
}; 

declare
  %rest:GET
  %rest:path("/{$lang}/converter/{$converter-id}")
  %output:method("html")
  %output:html-version('5')
function tr:converter-page($converter-id as xs:string, $lang as xs:string := 'de'){
  let $converter := conv:get($converter-id),
      $title := $converter/xs:string(@name),
      $parameters := $converter/inputs/*,
      $url := '/converter/' || $converter-id,
      $context := map {'title': $title, 'lang': $lang, 'url':$url}
  return
    element html {
      config:get-html-head($context),
      element body {
        config:get-html-header($context),
        element details {
          attribute class {'well'},
          element summary {'Admin'},
          hf:create-anchor('/' || $lang || '/converter/' || $converter-id || '/runs','Vorherige Konvertierungen')
        },
        element div {
          attribute class {'well'},
          element form {
            attribute action {'/' || $lang || '/converter/' || $converter-id || '/convert'},
            attribute method {'POST'},
            attribute enctype {"multipart/form-data"},
            for $p in $parameters
            return tr:parameter-to-html($p, $lang),
            element form-group{
              element label {
                i18n:val("upload",$lang)
              },
              element input {
                attribute type {'text'},
                attribute required {''},
                attribute readonly {''},
                attribute name {'file-name'},
                attribute id {'file-name'},
                attribute class {'form-control invalid'},
                attribute onclick {"document.querySelector('#upload_file_uploaded_data').click();document.querySelector('#submit-to-conversion').classList.remove('disabled');"},
                attribute placeholder {i18n:val("select-file",$lang)},
                attribute autocomplete {'off'}
              },
              element input {
                attribute type {'file'},
                attribute id {'upload_file_uploaded_data'},
                attribute name {'upload_file_uploaded_data'},
                attribute class {'hidden'}
              },
              element button {
                attribute id {'submit-to-conversion'},
                attribute disabled {},
                attribute class {'primary-btn disabled'},
                attribute type {'submit'},
                i18n:val("submit",$lang)
              }
            }
          }
        }
      }
    }
};

declare function tr:parameter-to-html($input as element(*), $lang as xs:string := 'de'){
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
