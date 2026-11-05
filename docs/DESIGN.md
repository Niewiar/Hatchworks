# Hatchworks Design Doc

Hatchworks to stylizowana gra 3D o tworzeniu ekosystemu przez hodowanie osobliwych stworzeń. Gracz odkrywa nowe rzeczy, zdobywa jaja, organizuje teren i buduje urządzenia. Stworki zmieniają otoczenie, dostarczając roślin i materiałów potrzebnych do dalszego rozwoju.

Ten dokument opisuje obecne zasady oraz wskazuje pomysły, które czekają na decyzję. Parametry rozgrywki zmieniamy w bazie danych. Edycja samego Design Doc nie zmienia zachowania gry. Podane wartości opisują ustawienia startowe i trzeba je aktualizować po zmianach balansu.

## Główna pętla gry

- Odkrywamy pojęcia przez łączenie dwóch znanych elementów oraz obserwowanie świata.
- Pierwsze odkrycia mogą dawać przedmioty, między innymi jaja i sadzonki. Odkrycia budynków odblokowują ich budowanie.
- Inkubujemy jaja, wykluwamy stworki i zapewniamy im odpowiednią przestrzeń oraz jedzenie.
- Stworki tworzą trawę, sadzą rośliny albo przekształcają grunt. Gracz zbiera włókno, zioła, drewno i kamień.
- Budujemy kolejne urządzenia i ogrodzenia, modelujemy teren oraz rozwijamy kolekcję odkryć i gatunków.

Nie ma odwiedzających. Budowanie siedlisk służy organizacji ekosystemu. Projekt zachowuje charakter gry inkrementalnej.

## Początek gry i teren

Nowa gra zaczyna się na płaskiej, jałowej glebie, z odkryciami Soil i Life, bez budynków i surowców. Pierwszy inkubator trzeba odkryć i postawić. Obniżenie terenu odsłania wodę znajdującą się na stałym poziomie pod mapą.

Gracz ma narzędzia podnoszenia, obniżania, wygładzania i spłaszczania terenu. Malowanie i zbieranie podłoża korzystają z zapasu trawy, piasku oraz skalnego gruntu, mierzonego w m². Gracz zaczyna z zerowym zapasem. Zbiór zamienia podłoże w pustą glebę, a malowanie zużywa zebrany materiał. Gleby nie malujemy i nie traktujemy jako surowca. Typy gruntu powstają przede wszystkim dzięki działalności stworków. Mech nie jest już typem terenu ani osobnym surowcem.

Ogrodzenia wyznaczają połączone regiony i blokują przejścia. Region przechowuje powierzchnię, udział wody i pokrycie typami gruntu. AI pyta, w jakim regionie znajduje się stworek, zamiast samodzielnie analizować cały świat. Widok Regiony pokazuje granice i skład podłoża. Inspekcja flory nie jest obecnie trybem gracza.

Nowe rośliny nie wyrastają samoczynnie. Pojawiają się przez sadzenie, działalność stworków lub ustawienie początkowego świata. Posadzone rośliny mogą następnie rosnąć do pełnej wielkości.

Każda zebrana roślina i każde całkowicie ścięte drzewo ma niezależnie 30 procent szans na jedną sadzonkę tego samego gatunku. Częściowe uderzenia w drzewo, niedojrzałe lub już zebrane rośliny oraz rośliny zgniecione przez Pebblita nie dają sadzonek. Sadzonka trafia do plecaka z animacją zdobycia. Parametr `sapling_chance` jest ustawiany osobno dla gatunku w katalogu Flora w zasobie gatunku przez Inspektor Godota; zakres 0–1 odpowiada 0–100 procent.


## Odkrycia i plecak

Pojęcia w odkryciach są wielokrotnego użytku. Połączenie A i B nie zużywa ich i nie wymaga przenoszenia fizycznych surowców z ekwipunku. Karty łączą się po puszczeniu trzymanej karty na drugiej. PPM usuwa kartę z planszy łączenia.

Zakładka odkrytych pojęć pokazuje znane receptury oraz znaki zapytania przy niepoznanych połączeniach. Niepoznane receptury są przed poznanymi. Odkrycia mają kategorie. Pierwsze poznanie receptury może dać punkty nauki; receptury budynków nie dają nauki.

Ważne połączenia obecnego początku gry:

- Soil + Soil daje Stone.
- Soil + Life daje Seed.
- Seed + Life daje Tuftling Egg.
- Stone + Life daje Incubator.
- Stone + Soil daje Boulder.
- Boulder + Life daje Pebblit Egg.
- Oak + Life daje Rootle Egg.
- Herbs + Life daje Bloomlet Egg.

Pierwsze odkrycie jaja daje jego sztukę do plecaka. Odkrycie flory może dać sadzonkę, którą można posadzić. Budynki są odblokowywane w katalogu budowy. Pierwsza sztuka każdego typu budynku jest domyślnie darmowa raz na zapis. Cena kolejnego zależy od obecnej liczby niezniszczonych budynków tego typu, a nie łącznej liczby wcześniejszych budów. Po utracie budynków maleje do ceny bazowej. Ruiny nie podnoszą ceny. Historia budów pozostaje zapisana wyłącznie na potrzeby jednorazowej darmowej sztuki.

Plecak zawiera przedmioty takie jak jaja i sadzonki. Surowce widoczne na górnym pasku nie są powtarzane w plecaku. Lot ikon do paska lub plecaka trwa dwie sekundy. Stan zasobów zmienia się od razu, a wyświetlany przyrost na pasku dopiero po dolocie animacji.

## Budynki i jaja

**Inkubator** przyjmuje jajo z plecaka, odlicza czas i przechodzi w stan gotowości do wyklucia. Gracz uruchamia prezentację wykluwania. Jajo jest początkowo pośrodku, skorupka rozpada się na fragmenty, a wykluty stworek przechodzi na lewo. Dopiero wtedy pojawia się karta z informacjami i przyciskiem akceptacji. Po akceptacji stworek trafia na wolne miejsce przy inkubatorze. Płeć jest losowana podczas wykluwania.

**Karmnik** przechowuje Plant Fiber. Gracz uzupełnia go z zasobów. Wszystkie obecne gatunki jedzą to samo pożywienie. Pusty, zalany lub nieosiągalny karmnik nie zatrzymuje pozostałych zachowań stworków.

**Warsztat życia** wytwarza poznane jaja za surowce i naukę. Gotowe jajo trzeba odebrać. Wytworzenie jaja nie wykluwa go ani nie zastępuje inkubatora. Projekt warsztatu zakłada ruchome elementy i pojawienie się jaja w centralnym miejscu na końcu pracy. Nie wymaga przyłącza rury ani energii.

Budynki i elementy drewnianego ogrodzenia mają wytrzymałość. Zniszczenie powoduje utratę zawartości. Warsztat pozostaje trwałą ruiną do uprzątnięcia; pozostałe zniszczone budynki są usuwane. W panelu obiektu jest naprawa. Kamienne ogrodzenie zostało usunięte.

## Gatunki i ich role

**Tuftling** pływa i nabiera wodę w futro. Następnie wychodzi na odpowiednią suchą glebę, otrzepuje się i tworzy trawiasty grunt oraz kępki trawy. Po udanym wysiewie musi ponownie udać się do wody. Obie płcie mają tę samą rolę.

**Rootle** szuka trawiastego miejsca i sadzi dąb lub krzew. Przy wyborze gatunku rośliny domyślnie ma 65 procent szans na dąb i 35 procent na krzew. Obie płcie mają tę samą rolę.

**Bloomlet** tworzy rośliny zielne na trawiastym podłożu. Obecna implementacja sadzi paprocie zbierane jako Herbs. Obie płcie mają tę samą rolę.

**Pebblit samiec** chodzi na czterech łapach. Tworzy skalne podłoże do wspólnego minimum 25 procent suchego lądu regionu. Podczas przekształcania delikatnie fałduje wysokość i może utworzyć złoże kamienia. Po osiągnięciu minimum nadal tworzy złoża na istniejącej skale. Gatunki mogą nadpisywać nawzajem swój teren, również piasek.

**Pebblit samica** tworzy piasek na glebie, trawie i skałach do wspólnego minimum 25 procent suchego lądu regionu, bez zmiany wysokości. Następnie produkuje na piasku małe kamyki, po jednym Stone do zebrania graczką. W czasie wolnym może podejść do złoża i się o nie ocierać.

Obie płcie Pebblita mogą niszczyć pobliskie drewniane płoty i budynki wyłącznie w stanie Nieszczęśliwy. Tłok wpływa na zadowolenie; nie uruchamia ataku z pominięciem nastroju.

## Jak działa AI kreatur

### Konstrukcja kontrolerów

AI rozróżnia nastrój wynikający z zadowolenia oraz graf wyboru zachowań. Wszystkie gatunki mogą jeść, pracować i odpoczywać przy każdym nastroju. Zadowolenie wyznacza serię1/2/3 prac, a nie tempo animacji. Spośród obecnych gatunków tylko nieszczęśliwy Pebblit może atakować.

- `Creature` obsługuje ciało, kolizje, podnoszenie, naturalne spadanie grawitacją i lądowanie, wygląd płci oraz podstawowe statystyki.
- `CreatureActivityController` ma jeden wspólny przebieg aktywności: ruch rozrodu, fazy specjalne, odświeżenie nawigacji, decyzję AI, jedzenie, odpoczynek i prowadzenie trasy. Jest wspólnym rodzicem kontrolerów gatunków.
- `TuftlingController` wybiera wodę i miejsce wysiewu oraz wykonuje kąpiel i wysiew trawy.
- `EcosystemCreatureController` jest drugim potomkiem wspólnego kontrolera. Wybiera i wykonuje zadania sadzenia roślin, tworzenia skał lub piasku.
- `PebblitController` dodaje własne pozy ciała, szarże, agresję i odpoczynek po szarży.
- `CreatureNavigation` planuje ścieżki, rezerwuje miejsca i pomaga stworkom omijać się nawzajem.
- `CreatureWellbeingController` przygotowuje wspólne informacje o mieszkańcach regionów, a `NoiseController` zlicza hałas.
- `BreedingController` steruje aktywną parą rozmnażających się stworków.

Kontroler zwraca `activity_presentation` z krótką nazwą, identyfikatorem ikony i opisem szczegółowym. Panel inspekcji i tooltip korzystają z tego samego opisu aktywności; UI nie interpretuje ponownie stanów pracy ani szarży. Numery aktywności i zapisane pola pozostają zgodne z wcześniejszym formatem zapisu.

### Kolejność zachowań

Podniesiony stworek podąża za dłonią gracza. Spadanie i lądowanie obsługuje fizyka. Po bezpiecznym postawieniu wraca do swoich decyzji.

Aktywne rozmnażanie przejmuje ruch i orientację pary. Fazy zwijania, uderzenia i rozwijania sterują szarżą Pebblita. Zmiana nastroju może przerwać niedozwolone zachowanie także w tych fazach. Po zakończonej lub przerwanej zmianą nastroju szarży Pebblit musi odbyć osobny odpoczynek.

Graf sprawdza pasujące reguły według priorytetu. Dostępne jedzenie, atak nieszczęśliwego Pebblita i należny odpoczynek mogą poprzedzać pracę. Nastrój nie blokuje produkcji żadnego gatunku. Zmiana zadowolenia zmienia długość serii i może zakończyć niedozwolony już atak; wykonane efekty nie są cofane ani powtarzane.

### Najedzenie i jedzenie

`satiety` ma zakres od 0 do 100. Spada z prędkością `100 / satiety_seconds` punktów na sekundę. Zatem `satiety_seconds` określa czas opróżnienia całego paska. Tuftling i Pebblit mają obecnie 120 sekund; wartość domyślna definicji gatunku to 240 sekund.

Poniżej `feeding_threshold` stworek okresowo szuka karmnika, który ma właściwe pożywienie, dostępną porcję i osiągalne miejsce jedzenia. Miejsce jest rezerwowane. Po dojściu trwa animacja jedzenia przez `feeding_seconds`, karmnik traci `food_per_feeding`, a stworek odzyskuje `satiety_per_meal` punktów najedzenia.

Jeżeli nie ma jedzenia, wolnego miejsca albo drogi, wyszukiwanie nie przejmuje AI. Stworek dalej pracuje lub odpoczywa, również przy zerowym najedzeniu. W zwykłych stanach ponawia próbę mniej więcej raz na sekundę. Zniknięcie karmnika lub jedzenia podczas drogi albo posiłku zwalnia rezerwację i przywraca zwykłe zachowania.

Zero najedzenia nie jest stanem śmierci i nie wyłącza AI. Głód wpływa na zadowolenie. Rozmnażanie ma osobny, jawny wymóg minimalnego najedzenia.

### Zadowolenie i wrażliwości

Wszystkie gatunki pracują przy każdym zadowoleniu. Nieszczęśliwy wykonuje 1 pracę, Neutralny 2, Zadowolony 3 przed czasem wolnym. Tempo animacji i liczników produkcji pozostaje stałe. Jedzenie, odpoczynek oraz ataki zachowują własne zasady; nie ma statystyki energii.

`happiness` to obecne zadowolenie, początkowo 75. `_happiness_target` to wartość, do której stworek stopniowo dochodzi. Mniej więcej raz na sekundę pobiera informacje o swoim regionie i otoczeniu.

Bieżące `happiness` wyznacza wspólny dla AI i panelu inspekcji nastrój: Nieszczęśliwy poniżej `unhappy_threshold` (domyślnie 40), Neutralny od tego progu do wartości poniżej `happy_threshold` (domyślnie 70), Zadowolony od górnego progu. Progi ustawia się osobno dla gatunku w zasobach gry przez Inspektor Godota. Wartość 40 należy do stanu Neutralny, a 70 do Zadowolony. Nastrój jest wyliczany z zapisanego zadowolenia i nie potrzebuje osobnego pola zapisu.

Docelowe zadowolenie liczymy tak:

```text
cel = 0.45 × najedzenie + 35 + premia za towarzystwo
      − 35 × stres tłoku
      − 25 × stres hałasu
      − 25 × stres obcych gatunków
      − terrain_happiness_penalty × brak spełnienia podłoża
wynik ograniczamy do przedziału 0–100
```

Premia za towarzystwo wynosi 20, jeżeli w tym samym regionie jest co najmniej jeden inny osobnik tego gatunku w zasięgu `company_radius`. Kolejni towarzysze nie mnożą tej premii.

Sucha powierzchnia regionu jest dzielona przez liczbę stworków korzystających ze wspólnego regionu. Stres tłoku to brakująca część `preferred_area`, pomnożona przez `crowding_sensitivity`. Stworki trzymane przez gracza nie zajmują tej przestrzeni.

Stres hałasu to lokalne natężenie pomnożone przez `noise_sensitivity`. Hałas tworzą pracujące maszyny, ścinanie, wydobycie i uderzenia Pebblita. Słabnie z odległością i z upływem czasu. Płoty i granice regionów go nie tłumią. Stworek ignoruje własne źródła hałasu.

Niechęć do gatunków jest zapisana w `species_aversions`. Działa, jeśli dany gatunek występuje w tym samym regionie, niezależnie od odległości. Wagi obecnych nielubianych gatunków sumują się do maksymalnie 1. Większa liczba osobników tego samego obcego gatunku nie mnoży jego wagi.

Wrażliwości są cechami gatunku. Obie płcie korzystają z tych samych ustawień. To nie są obecnie indywidualnie losowane charaktery.

`happiness_response_seconds` określa tempo zmiany zadowolenia: `100 / happiness_response_seconds` punktów na sekundę. Przy wartości 30 różnica 10 punktów wyrównuje się w około 3 sekundy, a różnica pełnych 100 punktów w 30 sekund. Nie jest to sztywny czas oczekiwania na każdą zmianę.

Wszystkie gatunki pracują przy każdym zadowoleniu. Nieszczęśliwy wykonuje 1 pracę, Neutralny 2, Zadowolony 3 przed czasem wolnym. Tempo animacji i liczników produkcji pozostaje stałe. Jedzenie, odpoczynek oraz ataki zachowują własne zasady; nie ma statystyki energii.

### Wybieranie pracy i odpoczynek

Kontroler szuka miejsca w pobliżu, sprawdzając grunt, wodę, nachylenie, wolną przestrzeń, lokalny limit wytworzonych obiektów i możliwość dojścia. Dla zadań ekosystemowych wykonuje do 40 prób losowego wyboru miejsca w zasięgu `production_radius`.

Sadzenie, uderzenie lub tworzenie piasku jest związane z określonym momentem animacji. `_effect_done` zapobiega wielokrotnemu wykonaniu tego samego efektu w trakcie jednej pracy i pomaga zachować poprawny stan po wczytaniu gry.

Po udanej pracy stworek od razu podejmuje następną pracę w serii. Po 1/2/3 ukończonych pracach, zależnie od nastroju, przechodzi do czasu wolnego o długości leisure_seconds_min–leisure_seconds_max. Nieudana próba nie zwiększa licznika. Opóźnienie resting_seconds dotyczy oczekiwania na dostępne zadanie. Zwykłe obiekty flory i złóż zachowują limity; brak jedzenia nie blokuje innych dostępnych zachowań.

### Agresja Pebblita

Pebblit może rozpocząć atak tylko w nastroju Nieszczęśliwy, czyli domyślnie przy `happiness < 40`. Neutralny i Zadowolony nie atakują. Nie ma osobnego progu agresji ani bezpośredniego wyzwalacza ataku od małej powierzchni. Brak miejsca obniża zadowolenie przez zwykły system wrażliwości.

Nowa szarża wymaga suchego gruntu, gotowej nawigacji, zakończonego odpoczynku i dostępnego celu. Kontroler sprawdza budynki oraz drewniane płoty w zasięgu `production_radius + 2` metry i szuka najbliższego celu, do którego może podejść i uderzyć bez trafiania przez przeszkodę. Gdy nie ma celu ataku, nieszczęśliwy Pebblit może normalnie pracować. Próby wyboru agresywnego celu są ograniczone odstępem około 0.8 sekundy.

Domyślne obrażenia `impact_damage` wynoszą 25. Każda ukończona szarża kończy się obowiązkowym odpoczynkiem `aggression_cooldown`, domyślnie 12 sekund. Po nim Pebblit sprawdza warunki ponownie. Jeśli nadal jest nieszczęśliwy, może znowu zaatakować. Jest to cykl szarży i odpoczynku, a nie zużywanie paska energii.

### Nawigacja i wspólne miejsca

Ścieżki statyczne korzystają z siatki AStarGrid2D, domyślnie o komórkach 0.5 metra. Nawigacja uwzględnia regiony, wysokość i nachylenie terenu, wodę, ogrodzenia, budynki, drzewa, krzewy i skały. Przebudowuje dane po zmianie świata, partiami, zamiast liczyć całą mapę osobno dla każdego stworka.

Miejsca kąpieli, pracy, jedzenia i spotkania pary mogą być rezerwowane. Ruch innych stworzeń obsługują kolizje, lokalne omijanie, ustępowanie i przepychanie. Nie przebudowujemy całej siatki dla każdego ich kroku.

Gdy stworek przez około dwie sekundy prawie nie posuwa się po ścieżce, kontroler odrzuca problematyczny ruch i próbuje ponownie wybrać trasę lub zadanie. Nieudane miejsca są czasowo zapamiętywane. Podniesienie lub usunięcie stworka zwalnia jego rezerwacje.

### Rozmnażanie

Rozmnażanie uruchamiamy przyciskiem w panelu potworka. Nawoływać może samiec i samica. Wybrany osobnik pozostaje na miejscu, a jeden gotowy osobnik przeciwnej płci i tego samego gatunku podchodzi do niego. Partner jest wybierany według długości osiągalnej drogi.

Oboje potrzebują suchego podłoża, wymaganego typu terenu w regionie i odpowiedniego najedzenia. Tuftling dodatkowo potrzebuje dostępnej wody. Domyślnie rozpoczęcie wymaga 60 procent najedzenia, nawoływanie trwa przynajmniej 3 sekundy, a bliski kontakt z serduszkami 6 sekund. Po udanym rozrodzie każdy traci 20 punktów najedzenia i ma 120 sekund przerwy.

Jajo pojawia się na wolnej ziemi. Kliknięcie zbiera je do plecaka. Podniesienie rodzica, utrata koniecznych warunków albo zbyt niskie najedzenie podczas rozrodu mogą przerwać parę bez powstania jaja.

### Zapis i granice obecnego AI

Zapis obejmuje statystyki, płeć, postęp czynności, znaczniki wykonanych efektów, przerwy i aktywne zadania. Po wczytaniu nawigacja i przejściowe ścieżki są odtwarzane na podstawie świata.

Przegląd obecnego kodu zapisu wskazuje niespójność aktywnego rozrodu: odczyt pary zachowuje starszy układ samiec/samica i nie odtwarza pól `caller` oraz `caller_position`, z których korzysta obecny kontroler. Wznowienie takiej pary po wczytaniu wymaga osobnej poprawki i testu; nie należy traktować go jako zweryfikowanego.

Nie ma systemu uczenia się, pamięci relacji między konkretnymi osobnikami ani samodzielnego planowania łańcucha gospodarki. Stworki wybierają kolejne dostępne czynności według stanów i priorytetów. Warunki rozrodu, warunki pracy i samopoczucie są powiązane, ale stanowią osobne kontrole.

## Nauka i rozwój

Nauka pochodzi z pierwszego poznania receptur, pierwszych zaobserwowanych działań gatunku oraz powtarzalnych projektów naukowych opłacanych materiałami. Obserwacje obejmują między innymi wyklucie, pracę i rozmnażanie; powtórzenie tej samej obserwacji nie odnawia nagrody. Odkrycia budynków nie dają nauki.

Kolejne jaja z warsztatu zużywają surowce i naukę. Ekosystem odnawia surowce, a projekty pozwalają przeznaczać ich nadwyżki na naukę. Tempo uzupełniania projektów i koszt materiałów regulują długoterminową produkcję jaj.

## Dane projektu

Gra korzysta z natywnych zasobów Godota. Katalog główny znajduje się w `resources/database/game_database.tres`, a parametry gatunków, flory, budynków i odkryć edytuje się przez Inspektor Godota. Ten dokument pozostaje opisem zasad i decyzji projektu; edycja tekstu nie zmienia parametrów rozgrywki.

Interfejs gry jest zbudowany ze scen Control i Container. Skrypty wiążą dane, widoczność i zdarzenia.

## Pomysły wymagające dalszych decyzji

- Docelowy długofalowy cel ekosystemu i zakończenie kolejnych etapów rozwoju.
- Dalszy balans nauki, kosztów jaj i cen rosnącej liczby budynków.
- Rury i połączenia pomiędzy maszynami. Same przyłącza w modelach nie oznaczają gotowej sieci przepływu.
- Zakres niszczenia w szale Pebblita poza obecnymi płotami i budynkami, na przykład rośliny i skały.
- Kolejne gatunki, zależności między nimi i bardziej rozbudowane środowiska.

### Krajobraz regionu i graczka

Minima terenu zapisujemy procentowo w terrain_minimums i female_terrain_minimums gatunku. Samice korzystają z niepustego profilu samic, a w pozostałych przypadkach z bazowego. Na start: Tuftling, Rootle i Bloomlet wymagają 50% trawy, samiec Pebblita 25% skały, samica 25% piasku. Rootle i Bloomlet nadal tworzą wyłącznie florę, więc trawiasty krajobraz zapewnia im Tuftling albo gracz. Minimum jest wspólne w regionie i nie rośnie z liczbą osobników; mianownikiem jest suchy ląd. Gatunki mogą przekształcać nawzajem swój teren.

LandscapeController pilnuje niedoboru przy wyborze zadania i wykonaniu efektu. Efekty podłoża, wysokości i rozsiewu są przycinane do aktualnego regionu; przebudowa płotów, zalanie i modelowanie terenu odświeżają pomiary. Po osiągnięciu minimum stworek przestaje zmieniać teren, ale nadal może sadzić na właściwym podłożu. Samica Pebblita pozostawia wtedy małe kamyki na piasku.

Graczka zastępuje pędzel zbierania roślin. Przytrzymanie PPM prowadzi ostrze po ziemi; zbierany jest cały odcinek ruchu, więc szybkie przeciągnięcie nie pomija roślin ani kamyków. Zbieramy niskie rośliny i małe kamienie; drzewa oraz duże złoża wymagają siekiery i kilofa. Kamyk daje 1 kamień jako zasób. Przerwanie kontaktu przez UI nie zbiera po drugiej stronie przerwy. Puszczenie PPM kończy pracę, a Esc lub główny przycisk zamyka tryb.

### Ataki na budynki

Usunięto cały system oznaczeń nad budynkami, w tym wykrzykniki. Każde rzeczywiste trafienie w budynek daje osobny popup z dotychczasowym czasem, przyciskiem X i limitem 10 widocznych kart. Kliknięcie kadruje budynek i napastnika płynnym ruchem kamery. Po zniszczeniu obiektu używany jest zapisany obszar trafienia. Alert nie włącza trwałego focusu inspekcji i jest widoczny również podczas zwykłej inspekcji.


## Informacje o stworku

Panel inspekcji pokazuje nazwę, płeć i bieżącą czynność, zadowolenie oraz jego aktualne warunki, najedzenie i akcję rozrodu. Bezpośrednio pod zadowoleniem jest spełnienie warunku suchej przestrzeni na mieszkańca, a obok pozostałe przyczyny komfortu lub dyskomfortu. Statyczne współczynniki wrażliwości pozostają w danych projektowych. Panel gracza używa spójnych ikon, krótkich stanów i własnych tooltipów. Preferowane podłoże jest dodatkowym warunkiem: jego ikona, bieżący udział, regionalne minimum i pasek spełnienia znajdują się pod warunkami nastroju. Dotyczy suchego lądu regionu, niezależnie od przestrzeni na mieszkańca.

Parametry gatunków edytujemy w natywnym Hatchworks Forge, w kategoriach dopasowanych do rzeczywistej roli. Wartości podłoża i niechęci mają nazwane kontrolki procentowe. Pełny schemat danych zachowuje starsze szkice i walidację także wtedy, gdy pola nie są widoczne w danej kategorii. Strona HTML została wycofana.


## Spełnienie podłoża i ręczna zmiana krajobrazu

Pasek preferowanego podłoża korzysta z tego samego pomiaru suchego lądu oraz wspólnego maksimum wymagań mieszkańców co AI. Trawa 30% przy wymaganych 50% daje 60% spełnienia. Niedobór obniża zadowolenie proporcjonalnie: domyślnie maksymalnie 25 punktów przy braku podłoża,10 przy 60% spełnienia i 0 po osiągnięciu minimum. Maksymalną karę ustawia się dla gatunku w Forge w kategorii Zadowolenie. Przebudowa regionu nie zeruje ostatniego poprawnego pomiaru.

Malowanie ma osobny przycisk główny. Zbieranie podłoża jest narzędziem w Zbieraniu, obok graczki, siekiery i kilofa. Oba używają LPM oraz koła myszy do zmiany pędzla; PPM zamyka tryb. Graczka nadal zbiera po przytrzymaniu PPM. Ubytki zapasu są natychmiastowe; przyrost licznika na pasku następuje po dolocie ikony. Zapasy podłoża mają drugi rząd paska i jednostkę m².

Koszt odpowiada rzeczywiście dodanej powierzchni materiału po zapisie pikseli, a zbiór rzeczywiście usuniętej powierzchni. Pusta gleba nie daje surowców i ponowny zbiór nie powiela zapasu. Nadpisanie innego materiału podczas malowania nie oddaje go graczowi. Zmiana podłoża odświeża cele krajobrazu i zadowolenie stworków w czasie działania gry. Starsze zapisy otrzymują zerowe nowe zapasy podłoża.


## Ceny budynków i handlarz (2026-11-03)

Budynki każdego typu mają oddzielną cenę bazową i progresję. Dla domyślnej progresji liniowej 50%: pierwszy w zapisie jest darmowy, przy jednym istniejącym następny kosztuje cenę bazową, przy dwóch 150%, przy trzech 200%. Po utracie wszystkich budynków odbudowa kosztuje cenę bazową; darmowa sztuka nie wraca. Ruiny warsztatu i obiekty oczekujące na usunięcie nie wchodzą do liczby wyznaczającej cenę. Zapis wersji 1 nadal przechowuje historię wykorzystania darmowej sztuki.

Handlarz jest osobnym kompaktowym panelem otwieranym z głównego paska. Jego wysokość wynika z zawartości. Nie pokazuje przycisku zamiany stron, opisu prowizji ani dodatkowej instrukcji o podłożach. Nie wymaga budynku ani obecności stworka. Przyjmuje włókno, drewno, kamień, zioła oraz zapasy trawy, piasku i skalnego gruntu. Surowce liczymy w całych sztukach, podłoża w setnych częściach m². Nauka może być środkiem płatności, ale nie jest oferowana w zamian za zasoby.

| Towar | Wartość jednostki do barteru | Zakup za 1 punkt nauki |
|---|---:|---:|
| Włókno | 1 | 12 |
| Drewno | 2 | 6 |
| Kamień | 1 | 12 |
| Zioła | 4 | 3 |
| Trawa | 2 za m² | 6 m² |
| Piasek | 1 za m² | 12 m² |
| Skalny grunt | 2 za m² | 6 m² |

Prowizja barteru wynosi 25% wartości oddawanej oferty. Ilość otrzymana = ilość oddawana × wartość źródła × 0.75 / wartość celu, zaokrąglona w dół do całej sztuki lub 0.01 m². Na przykład 8 włókna daje 3 drewna, a 8 drewna daje 12 kamieni. Zakupy za naukę korzystają z osobnego stałego kursu wartości 12 na punkt; prowizja nie jest doliczana po raz drugi. Wartości towarów edytuje się w ResourceDefinition.trade_value, a prowizję i kurs nauki w WorldBalance.

Panel pokazuje ilości przed i po transakcji oraz powód niedostępnej wymiany. Zatwierdzenie ponownie sprawdza aktualny stan, pobiera zapłatę i dodaje wynik przez wspólny ekwipunek oraz system zdobywania zasobów. Nie można kupić na kredyt, wymienić tego samego towaru ani wykonać transakcji z zerowym wynikiem. Ilości wykraczające poza format zapisu są odrzucane przed pobraniem zapłaty.

Handel pozwala zamienić nadwyżkę albo naukę na brakujący materiał. Osobne projekty naukowe odnawiają naukę w zamian za materiały. Całkowicie pusty magazyn i brak nauki nadal wymagają zbierania lub produkcji zasobów w świecie.


## Projekty naukowe

„Projekty” to osobny przycisk głównego paska i pełne okno z trzema kartami. Karta przedstawia nazwę badania, opis, wymagane materiały z saldem, nagrodę i przycisk „Przekaż materiały”. Wymiana jest natychmiastowa; nie rozpoczyna dodatkowego procesu produkcyjnego ani nie wymaga budynku.

Pierwszy zestaw powstaje po poznaniu lub zdobyciu materiałów potrzebnych do co najmniej jednego projektu. Przy niewielkiej liczbie znanych materiałów oferty mogą dotyczyć tego samego badania w różnych wielkościach. Nowe miejsca są uzupełniane pojedynczo, co pięć minut czasu rozgrywki. Pełna tablica i pauza zatrzymują odliczanie; czas poza grą nie jest naliczany. Oferty pozostają dostępne do ukończenia. Gdy jest to możliwe, tablica zawiera projekt z nagrodą jednego punktu.

Katalog zawiera badania włókien, słojów drewna, ziaren kamienia, ziół, darni, piasku, skalnego podłoża oraz dwa projekty wymagające mieszanych materiałów. Warianty powiększają koszty i nagrody proporcjonalnie. Wartość kosztu wynosi co najmniej 150% wartości materiałów, które można kupić u Handlarza za przyznawaną naukę. Przykładowe podstawowe projekty: 18 włókna → 1 punkt, 9 drewna → 1 punkt, 12 włókna i 6 ziół → 2 punkty. To wstępny balans do obserwacji podczas rozgrywki.

Oferty, pozostały czas, identyfikatory i stan generatora losowego należą do zapisu świata. Ponowne otwarcie okna lub wczytanie gry nie odnawia tablicy. Starsze zapisy pozostają zgodne. Parametry i definicje edytuje się przez zasoby bazy danych w Godocie.


## Dobór płci przy wykluwaniu

Pierwsze otwarcie prezentacji wyklucia losuje płeć na podstawie żywych stworków tego samego gatunku na całej mapie, niezależnie od regionu. Do wagi każdej płci dodajemy liczbę osobników przeciwnej płci oraz 1. Dzięki temu rzadziej występująca płeć ma większą szansę, a obie możliwości pozostają dostępne. Szansa na samicę wynosi (samce+1)/(samce+samice+2); szansa na samca jest dopełnieniem. Brak stworków albo równa liczba obu płci daje 50/50. Przykłady: jeden samiec i brak samic daje około 67% szans na samicę, dziewięć samców i brak samic około 91%.

Trzymane, spadające i lądujące stworki są częścią populacji. Inne gatunki, inne mapy, podglądy i obiekty oczekujące na usunięcie nie wpływają na losowanie. Gotowe jajo z już przypisaną płcią nie jest jeszcze osobnikiem populacji. Płeć pozostaje przypisana po anulowaniu prezentacji, braku miejsca oraz zapisie i odczycie. Nowe jajo jest losowane osobno; zaakceptowany stworek wpływa na kolejne losowania.

### Widoki mapy

Mały panel w prawym górnym rogu przełącza Normalny, Hałas i Regiony. Wybór widoku jest niezależny od narzędzi, nie zmienia kamery i pozostaje aktywny po zamknięciu okna. Pełne okna ukrywają panel i nakładkę. Nowa sesja zaczyna się w widoku Normalnym; format zapisu świata pozostaje bez zmian.

Hałas pokazuje sumę rzeczywistych źródeł i zanikających impulsów, z takim samym tłumieniem odległości jak NoiseController. Skala 0–100 opisuje natężenie, a nie indywidualny stres stworka. Źródła mają znaczniki, a tooltip przy kursorze podaje lokalny wynik i nazwę źródła pod znacznikiem. Nakładka zatrzymuje się razem z pauzą gry.

Regiony mają rozróżnialne barwy i ciemne granice zgodne z aktualnymi ogrodzeniami. Etykiety pokazują powierzchnię suchego lądu oraz procent trawy, gleby, piasku i skalistego podłoża według tego samego pomiaru LandscapeController co AI. Woda jest osobnym udziałem całej powierzchni regionu. Całkowicie zalany region pokazuje brak suchego lądu. Po oddaleniu kamery oraz przy braku miejsca etykiety przechodzą do numerów; pełny skład jest dostępny po najechaniu. Projektowane na ekran etykiety omijają HUD i siebie nawzajem.

MapOverlayController steruje bezpośrednio siatką nakładki, zgodną z aktualną geometrią terenu i poziomem wody. Widok Normalny wyłącza jej przetwarzanie; tekstura regionów odświeża się po zmianie granic lub powierzchni, a mapa hałasu wyłącznie podczas oglądania hałasu. Układ panelu i etykiet definiują sceny Control oraz kontenery. Tooltipy obsługuje wspólny TooltipController.
Panel widoków ma natywne marginesy 16 px od górnej i 24 px od prawej krawędzi oraz szerokość wynikającą ze sceny (minimum 260 px). Przebudowa pełnej siatki regionów jest zależna wyłącznie od topologii ogrodzeń; zmiany wysokości i wody odświeżają buforowane kotwice. Hałas pomija niezmienione źródła i używa ponownie bufora RF. UI w widoku Normalnym nie przetwarza klatek, a etykiety i tooltipy odświeżają się po zmianach danych lub kamery, bez cyklicznego ukrywania i pokazywania całych drzew Control. Weryfikacja poprawki wydajności: `../Hatchworks-workbench/map-views-performance-20261103/`.
Profilowanie normalnego widoku wskazało niezależne od masek przestoje przy wyborze miejsca pracy i odświeżaniu danych regionów. LandscapeController przechowuje przestrzenny indeks kwalifikujących się komórek z lokalną aktualizacją, zamiast skanowania całego regionu przy każdym zapytaniu; zachowuje najbliższe i rozproszone cele. RegionsController aktualizuje lokalnie sumy pokrycia i zalania, pozostawiając pełny pomiar dla zmian globalnych i topologii. Dotychczasowe wyniki procentów gruntu i wody oraz warunki rozrodu pozostają zgodne z pełnym algorytmem. Pusty naturalny podkład ma w shaderze osobną ścieżkę z mniejszą liczbą odczytów tekstur.

## Czas wolny Tuftlingów

Tuftlingi obu płci wybierają na początku przerwy sen, lokalny spacer albo spotkanie z drugim wolnym Tuftlingiem. Pozostają dotychczasowe serie 1/2/3 prac zależne od zadowolenia i wspólny budżet przerwy 8–16 sekund. Dojście jest częścią tego czasu. Odpoczynek nie wymaga statystyki energii i nie tworzy podłoża ani przedmiotów.

Sen ma osobną animację szkieletu i zamykane geometryczne powieki, dopasowane do teksturowanych oczu. Przejście animacji płynnie zamyka i otwiera oczy. Nad śpiącym pojawiają się powoli unoszące litery Z z PNG; pobudka i podniesienie od razu ukrywają oznaczenie. Śpiący nie odzywa się losowo. Preferowane miejsce jest suche, spokojne i trawiaste; brak trawy nie blokuje odpoczynku.

Spacer jest krótki, po suchym podłożu, w tym samym regionie. Ma własną obsługę zakończenia trasy, więc nie uruchamia pracy Tuftlinga. Nieosiągalny cel lub utknięcie kończą próbę; kolejna decyzja nie jest losowana co klatkę.

Spotkanie może połączyć dowolne dwie płcie. Oboje muszą mieć czas wolny, być na suchym lądzie w tym samym regionie i mieć dość czasu na podejście oraz zabawę. Para rezerwuje miejsca i po podejściu od razu zaczyna trzysekundową zabawę z podskokami przesuniętymi w czasie. Nie ma osobnego powitania bokami. Utrzymane są zwykłe kolizje. Jedna para prowadzi wspólny etap; podniesienie, głód, rozród, usunięcie partnera lub zmiana przejścia przerywają spotkanie i zwalniają rezerwacje.

Tuftling nie ma rąk. Jego zachowania korzystają z korzennych nóg, pochylenia ciała i listowia. Nie dodajemy pielęgnacji rękami, ocierania o drzewa ani rekreacyjnej kąpieli jako oddzielnych czynności czasu wolnego.

Zapis wersji 1 przechowuje opcjonalny stan czasu wolnego i powiązanie pary. Starsze zapisy bez tego pola pozostają obsługiwane. Oddzielnie zapisywany jest inicjator rozrodu, także samica; historyczny zapis bez inicjatora zachowuje dotychczasowy domyślny wybór samca.


## Poprawki animacji Tuftlinga (2026-11-04)

Obie płcie mrugają w Idle, pływają z wyraźnym ruchem napędowym nóg do tyłu i odciążonym powrotem, a podczas Call wykonują radosne podskoki. Nawołujący skacze w oczekiwaniu na partnera; podczas rozrodu skaczą oboje przy zachowanych serduszkach. Usunięto GreetLeft i GreetRight, pozostawiono Play. Krople i szelest mokrych liści towarzyszą całemu otrząsaniu Work; emisja i dźwięk kończą się z czynnością lub jej przerwaniem. Tuftling nie odtwarza przypisanego plusku Swim. Pozostałe gatunki zachowują wcześniejsze animacje i dźwięki.

## Zarządzanie budowlami

Osobny główny przycisk Zarządzaj otwiera Przesuń i Usuń. Przesuwanie działa przez dwa kliknięcia LPM: wybór budynku i zatwierdzenie nowego miejsca. PPM anuluje. Budynek zachowuje zawartość i postęp, wstrzymując produkcję na czas przenoszenia. Przytrzymanie R obraca płynnie podgląd zarówno przy nowej budowie, jak i przenoszeniu. Sprawdzanie podłoża, granic i przeszkód jest wspólne z budowaniem.

Usuwanie obejmuje budynki oraz pojedyncze przęsła płotu. Zwracamy 100% zapłaconych materiałów, bez zwrotu zawartości. Budynki z darmowej pierwszej budowy zwracają zero. Starsze zapisy bez kosztu stosują bazową cenę. Wspólne słupki oddają koszt tylko przy usunięciu ostatniego przęsła. Ruiny warsztatu nie mogą być przenoszone i nie dają materiałów przy uprzątnięciu. Rozbiórka nie przywraca uprawnienia do darmowej pierwszej sztuki.
