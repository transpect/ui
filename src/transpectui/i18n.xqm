module namespace i18n = 'http://le-tex.de/i18n';

declare variable $i18n:languages := 
  <languages>
    <language short='de'></language>
    <language short='en'></language>
    <language short='es'></language>
    <language short='fr'></language>
  </languages>;
declare variable $i18n:static-replacements := 
  <static-replacements>
    <static-replacement tag="upload">
      <replacement lang="de">Daten hochladen</replacement>
      <replacement lang="en">Upload Data</replacement>
      <replacement lang="es">Subir Datos</replacement>
      <replacement lang="fr">Télécharger des données</replacement>
    </static-replacement>
    <static-replacement tag="submit">
      <replacement lang="de">Hochladen</replacement>
      <replacement lang="en">Submit</replacement>
      <replacement lang="es">Entregar</replacement>
      <replacement lang="fr">Télécharger</replacement>
    </static-replacement>
    <static-replacement tag="select-file">
      <replacement lang="de">Datei hier auswählen</replacement>
      <replacement lang="en">Select File</replacement>
      <replacement lang="es">Seleccionar Archivo</replacement>
      <replacement lang="fr">Sélectionnez un fichier</replacement>
    </static-replacement>
    <static-replacement tag="to-results">
      <replacement lang="de">Zu den Ergebnissen</replacement>
      <replacement lang="en">Results</replacement>
      <replacement lang="es">A Los Resultados</replacement>
      <replacement lang="fr">Aux Résultats</replacement>
    </static-replacement>
    <static-replacement tag="running">
      <replacement lang="de">Läuft</replacement>
      <replacement lang="en">Running</replacement>
    </static-replacement>
    <static-replacement tag="stopped">
      <replacement lang="de">Beendet</replacement>
      <replacement lang="en">Stopped</replacement>
    </static-replacement>
    <static-replacement tag="login">
      <replacement lang="de">Login</replacement>
      <replacement lang="en">Login</replacement>
    </static-replacement>
    <static-replacement tag="result">
      <replacement lang="de">Ergebnis</replacement>
      <replacement lang="en">Result</replacement>
    </static-replacement>
    <static-replacement tag="logs">
      <replacement lang="de">Logs</replacement>
      <replacement lang="en">Logs</replacement>
    </static-replacement>
  </static-replacements>;

declare function i18n:val($tag, $lang) {
  i18n:static-replacement($tag, $lang)
};
declare function i18n:static-replacement($tag, $lang) {
  $i18n:static-replacements/static-replacement[@tag eq $tag]/replacement[@lang eq $lang]/text()
};

declare function i18n:name($input, $lang as xs:string := 'de') as xs:string{
  let $name := ($input/@*[local-name(.) eq 'name-' || $lang], $input/@name, $input/@name-en, $input/@name-en)[1] => xs:string(),
      $log := admin:write-log($lang || $name)
  return $name
};