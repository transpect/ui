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
    <static-replacement tag="prev-conversions">
      <replacement lang="de">Vorherige Konvertierungen</replacement>
      <replacement lang="en">Previous Conversions</replacement>
    </static-replacement>
    <static-replacement tag="submit">
      <replacement lang="de">Hochladen</replacement>
      <replacement lang="en">Submit</replacement>
      <replacement lang="es">Entregar</replacement>
      <replacement lang="fr">Télécharger</replacement>
    </static-replacement>
    <static-replacement tag="called">
      <replacement lang="de">abgerufen</replacement>
      <replacement lang="en">retrieved</replacement>
      <replacement lang="es">consultado</replacement>
      <replacement lang="fr">consulté</replacement>
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
    <static-replacement tag="results">
      <replacement lang="de">Ergebnisse</replacement>
      <replacement lang="en">Results</replacement>
      <replacement lang="es">Resultados</replacement>
      <replacement lang="fr">Résultats</replacement>
    </static-replacement>
    <static-replacement tag="conversions">
      <replacement lang="de">Konvertierungen</replacement>
      <replacement lang="en">Conversions</replacement>
    </static-replacement>
    <static-replacement tag="running">
      <replacement lang="de">Läuft</replacement>
      <replacement lang="en">Running</replacement>
    </static-replacement>
    <static-replacement tag="stopped">
      <replacement lang="de">Beendet</replacement>
      <replacement lang="en">Stopped</replacement>
    </static-replacement>
    <static-replacement tag="canceled">
      <replacement lang="de">Abgebrochen</replacement>
      <replacement lang="en">Canceled</replacement>
    </static-replacement>
    <static-replacement tag="pending">
      <replacement lang="de">In der Warteschlange</replacement>
      <replacement lang="en">Pending</replacement>
    </static-replacement>
    <static-replacement tag="login">
      <replacement lang="de">Anmelden</replacement>
      <replacement lang="en">Login</replacement>
    </static-replacement>
    <static-replacement tag="not-allowed-message">
      <replacement lang="de">Sie haben keinen Zugriff auf diese Ressource. Melden Sie sich mit einem anderen Nutzer an.</replacement>
      <replacement lang="en">Access to that resource denied. Login with another User.</replacement>
    </static-replacement>
    <static-replacement tag="login-failed">
      <replacement lang="de">Anmeldung fehlgeschlagen: Username/Passwort nicht korrekt.</replacement>
      <replacement lang="en">Login failed: Username/Password not correct.</replacement>
    </static-replacement>
    <static-replacement tag="back">
      <replacement lang="de">Zurück</replacement>
      <replacement lang="en">Back</replacement>
    </static-replacement>
    <static-replacement tag="logout">
      <replacement lang="de">Abmelden</replacement>
      <replacement lang="en">Logout</replacement>
    </static-replacement>
    <static-replacement tag="result">
      <replacement lang="de">Ergebnis</replacement>
      <replacement lang="en">Result</replacement>
    </static-replacement>
    <static-replacement tag="logs">
      <replacement lang="de">Logs</replacement>
      <replacement lang="en">Logs</replacement>
    </static-replacement>
    <static-replacement tag="cancel">
      <replacement lang="de">Abbrechen</replacement>
      <replacement lang="en">Cancel</replacement>
    </static-replacement>
    <static-replacement tag="pending-conversions">
      <replacement lang="de">Warteschlange</replacement>
      <replacement lang="en">Pending Conversions</replacement>
    </static-replacement>
    <static-replacement tag="running-conversions">
      <replacement lang="de">Laufende Konvertierungen</replacement>
      <replacement lang="en">Running Conversions</replacement>
    </static-replacement>
    <static-replacement tag="run">
      <replacement lang="de">Aufruf</replacement>
      <replacement lang="en">Run</replacement>
    </static-replacement>
    <static-replacement tag="finished-conversions">
      <replacement lang="de">Beendete Konvertierungen</replacement>
      <replacement lang="en">Finished Conversions</replacement>
    </static-replacement>
    <static-replacement tag="empty-pending">
      <replacement lang="de">Keine Konvertierungen in der Warteschlange</replacement>
      <replacement lang="en">No Pending Conversions</replacement>
    </static-replacement>
    <static-replacement tag="empty-running">
      <replacement lang="de">Keine Laufenden Konvertierungen</replacement>
      <replacement lang="en">No Running Conversions</replacement>
    </static-replacement>
    <static-replacement tag="empty-finished">
      <replacement lang="de">Keine Beendeten Konvertierungen</replacement>
      <replacement lang="en">No Finished Conversions</replacement>
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