$Kueche->set_label('K�che');
$Kueche_Temperatur->set_label('Raumtemperatur_K�che[%.1f�C]');
$Kueche_Heizung->set_label('Heizk�rper_K�che[%i%%]');
$HeizungKuecheZwang->set_label('Zwangsstellung_K�che');
$Kueche_Schrank->set_label('Oberschrank_K�che');
$Aussentemp->set_label('Au�entemperatur[%.1f�C]');
$Stromzaehler16bit->set_label('Stromz�hler[%ikWh]');
$Stromzaehler32bit->set_label('Stromz�hler[%ikWh]');
$Bad_Temperatur->set_label('Raumtemperatur Bad[%.1f�C]');
$Kueche->set_label('Deckenlicht_K�che');
$Wohnen_Stehlampen->set_label('Stehlampen_Wohnzimmer');

$gEG = new Group;
$gEG->set_label('Erdgescho�');
$gEG->add($EG_Wohnen);
$EG_Wohnen->set_label('Wohnzimmer');
$gEG->add($EG_Kueche);
$EG_Kueche->set_label('K�che');
$gEG->add($EG_Arbeiten);
$EG_Arbeiten->set_label('Arbeitszimmer');
$gEG->add($EG_Flur);
$EG_Flur->set_label('Eingangsbereich');

$gOG = new Group;
$gOG->set_label('Obergescho�');
$gOG->add($OG_Flur);
$OG_Flur->set_label('Flur');
$gOG->add($OG_Lena);
$OG_Lena->set_label('Kinderzimmer Garten');
$gOG->add($OG_Franka);
$OG_Franka->set_label('Kinderzimmer Stra�e');
$gOG->add($OG_Eltern);
$OG_Eltern->set_label('Elternschlafzimmer');
$gOG->add($OG_Bad);
$OG_Bad->set_label('Badezimmer');

$Arbeiten->set_label('Arbeitszimmer');

# if label starts with a ":" there will be no hyperlink to change the object
$F_Haustuere->set_label('Haust�re');
$F_Haustuere->set_icon('eg_flur');
$F_HWR->set_label('HWR');
$F_Kueche->set_label('K�che');
$F_Wohnen->set_label('Wohnzimmer');
$F_Essen->set_label('Esszimmer');
$F_HWRTuer->set_label('T�r HWR');
$F_HWRTuer->set_icon('innentuer');
$F_Franka->set_label('Franka');
$F_Lena->set_label('Lena');
$F_Eltern->set_label('Schlafzimmer');
$F_Bad->set_label('Bad');
$F_Arbeiten->set_label('Arbeitszimmer');

$Arbeiten_Rollladen->set_label('Arbeitszimmer');
$Wohnen_Rollladen->set_label('Wohnzimmer');
$Essen_Rollladen->set_label('Esszimmer');
$Eltern_Rollladen->set_label('Schlafzimmer');
$Lena_Rollladen->set_label('Lena');
$Franka_Rollladen->set_label('Franka');

$Kueche_Temperatur->set_icon('temperatur');
$Bad_Temperatur->set_icon('temperatur');
$Aussentemp->set_icon('temperatur');

$Bad_Heizung->set_icon('heizungsventil');
$Kueche_Heizung->set_icon('heizungsventil');
$HeizungBadZwang->set_icon('heizungsventil');
$HeizungKuecheZwang->set_icon('heizungsventil');
