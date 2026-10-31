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

Gracz ma narzędzia podnoszenia, obniżania, wygładzania i spłaszczania terenu. Malowanie oraz zbieranie typów podłoża zostały usunięte. Typy gruntu powstają przede wszystkim dzięki działalności stworków. Mech nie jest już typem terenu ani osobnym surowcem.

Ogrodzenia wyznaczają połączone regiony i blokują przejścia. Region przechowuje powierzchnię, udział wody i pokrycie typami gruntu. AI pyta, w jakim regionie znajduje się stworek, zamiast samodzielnie analizować cały świat. Inspekcja regionów i flory nie jest obecnie trybem gracza.

Nowe rośliny nie wyrastają samoczynnie. Pojawiają się przez sadzenie, działalność stworków lub ustawienie początkowego świata. Posadzone rośliny mogą następnie rosnąć do pełnej wielkości.

Każda zebrana roślina i każde całkowicie ścięte drzewo ma niezależnie 30 procent szans na jedną sadzonkę tego samego gatunku. Częściowe uderzenia w drzewo, niedojrzałe lub już zebrane rośliny oraz rośliny zgniecione przez Pebblita nie dają sadzonek. Sadzonka trafia do plecaka z animacją zdobycia. Parametr `sapling_chance` jest ustawiany osobno dla gatunku w katalogu Flora w Godocie i na stronie; zakres 0–1 odpowiada 0–100 procent.


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

Pierwsze odkrycie jaja daje jego sztukę do plecaka. Odkrycie flory może dać sadzonkę, którą można posadzić. Budynki są odblokowywane w katalogu budowy. Pierwsza sztuka każdego budynku jest domyślnie darmowa, a ceny kolejnych wynikają z parametrów progresji ceny w bazie. Usunięcie budynku nie cofa historii jego ceny.

Plecak zawiera przedmioty takie jak jaja i sadzonki. Surowce widoczne na górnym pasku nie są powtarzane w plecaku. Lot ikon do paska lub plecaka trwa dwie sekundy. Stan zasobów zmienia się od razu, a wyświetlany przyrost na pasku dopiero po dolocie animacji.

## Budynki i jaja

**Inkubator** przyjmuje jajo z plecaka, odlicza czas i przechodzi w stan gotowości do wyklucia. Gracz uruchamia prezentację wykluwania. Jajo jest początkowo pośrodku, skorupka rozpada się na fragmenty, a wykluty stworek przechodzi na lewo. Dopiero wtedy pojawia się karta z informacjami i przyciskiem akceptacji. Po akceptacji stworek trafia na wolne miejsce przy inkubatorze. Płeć jest losowana podczas wykluwania.

**Karmnik** przechowuje Plant Fiber. Gracz uzupełnia go z zasobów. Wszystkie obecne gatunki jedzą to samo pożywienie. Pusty, zalany lub nieosiągalny karmnik nie zatrzymuje pozostałych zachowań stworków.

**Warsztat życia** wytwarza poznane jaja za surowce i naukę. Gotowe jajo trzeba odebrać. Wytworzenie jaja nie wykluwa go ani nie zastępuje inkubatora. Projekt warsztatu zakłada ruchome elementy i pojawienie się jaja w centralnym miejscu na końcu pracy. Nie wymaga przyłącza rury ani energii.

Budynki i elementy drewnianego ogrodzenia mają wytrzymałość. Zniszczenie usuwa obiekt i powoduje utratę zawartości. W panelu obiektu jest naprawa. Kamienne ogrodzenie zostało usunięte.

## Gatunki i ich role

**Tuftling** pływa i nabiera wodę w futro. Następnie wychodzi na odpowiednią suchą glebę, otrzepuje się i tworzy trawiasty grunt oraz kępki trawy. Po udanym wysiewie musi ponownie udać się do wody. Obie płcie mają tę samą rolę.

**Rootle** szuka trawiastego miejsca i sadzi dąb lub krzew. Przy wyborze gatunku rośliny domyślnie ma 65 procent szans na dąb i 35 procent na krzew. Obie płcie mają tę samą rolę.

**Bloomlet** tworzy rośliny zielne na trawiastym podłożu. Obecna implementacja sadzi paprocie zbierane jako Herbs. Obie płcie mają tę samą rolę.

**Pebblit samiec** chodzi na czterech łapach. Podczas pracy uderza w grunt, delikatnie zmienia wysokość, zamienia ziemię i trawę w skalne podłoże oraz może utworzyć złoże kamienia. Piasek jest chroniony przed tym przekształceniem.

**Pebblit samica** tworzy piaszczyste polany na glebie, trawie i skałach, bez tworzenia złóż kamienia i bez zmiany wysokości. Praca zatrzymuje się po osiągnięciu lokalnego limitu pokrycia piaskiem, domyślnie 30 procent. W czasie wolnym samica może podejść do skały i się o nią ocierać.

Obie płcie Pebblita mogą niszczyć pobliskie drewniane płoty i budynki, gdy są niezadowolone albo mają za mało miejsca.

## Jak działa AI kreatur

### Konstrukcja kontrolerów

AI jest maszyną stanów ze stałą kolejnością decyzji. Nie wybiera zachowań za pomocą modelu językowego, drzewa zachowań ani losowania pomiędzy wszystkimi możliwymi zadaniami.

- `Creature` obsługuje ciało, kolizje, podnoszenie, spadanie i lądowanie, wygląd płci, podstawowe statystyki oraz prędkość pracy wynikającą z zadowolenia.
- `TuftlingController` dodaje szukanie jedzenia, wody i miejsca wysiewu, pływanie, pracę oraz odpoczynek.
- `EcosystemCreatureController` korzysta ze wspólnych zasad Tuftlinga, ale wybiera zadania sadzenia roślin, tworzenia skał lub piasku.
- `PebblitController` dodaje własne pozy ciała, szarże, agresję i odpoczynek po szarży.
- `CreatureNavigation` planuje ścieżki, rezerwuje miejsca i pomaga stworkom omijać się nawzajem.
- `CreatureWellbeingController` przygotowuje wspólne informacje o mieszkańcach regionów, a `NoiseController` zlicza hałas.
- `BreedingController` steruje aktywną parą rozmnażających się stworków.

### Kolejność zachowań

Podniesiony stworek podąża za dłonią gracza. Spadanie i lądowanie obsługuje fizyka. Po bezpiecznym postawieniu wraca do swoich decyzji.

Aktywne rozmnażanie przejmuje ruch i orientację pary. Pebblit wykonujący zwijanie, uderzenie lub rozwijanie kończy odpowiednią fazę animacji. Po zakończonej szarży musi odbyć osobny odpoczynek.

Przy zwykłym podejmowaniu decyzji stworek najpierw sprawdza możliwość jedzenia. Następnie Pebblit może rozpocząć nowy atak. Dalej wykonywane są czas wolny, rozpoczęta praca, przejście po ścieżce albo wybór następnego zadania. Rozpoczęte fazy animacji mogą czasowo opóźnić wybór kolejnej czynności.

### Najedzenie i jedzenie

`satiety` ma zakres od 0 do 100. Spada z prędkością `100 / satiety_seconds` punktów na sekundę. Zatem `satiety_seconds` określa czas opróżnienia całego paska. Tuftling i Pebblit mają obecnie 120 sekund; wartość domyślna definicji gatunku to 240 sekund.

Poniżej `feeding_threshold` stworek okresowo szuka karmnika, który ma właściwe pożywienie, dostępną porcję i osiągalne miejsce jedzenia. Miejsce jest rezerwowane. Po dojściu trwa animacja jedzenia przez `feeding_seconds`, karmnik traci `food_per_feeding`, a stworek odzyskuje `satiety_per_meal` punktów najedzenia.

Jeżeli nie ma jedzenia, wolnego miejsca albo drogi, wyszukiwanie nie przejmuje AI. Stworek dalej pracuje lub odpoczywa, również przy zerowym najedzeniu. W zwykłych stanach ponawia próbę mniej więcej raz na sekundę. Zniknięcie karmnika lub jedzenia podczas drogi albo posiłku zwalnia rezerwację i przywraca zwykłe zachowania.

Zero najedzenia nie jest stanem śmierci i nie wyłącza AI. Głód wpływa na zadowolenie. Rozmnażanie ma osobny, jawny wymóg minimalnego najedzenia.

### Zadowolenie i wrażliwości

`happiness` to obecne zadowolenie, początkowo 75. `_happiness_target` to wartość, do której stworek stopniowo dochodzi. Mniej więcej raz na sekundę pobiera informacje o swoim regionie i otoczeniu.

Docelowe zadowolenie liczymy tak:

```text
cel = 0.45 × najedzenie + 35 + premia za towarzystwo
      − 35 × stres tłoku
      − 25 × stres hałasu
      − 25 × stres obcych gatunków
wynik ograniczamy do przedziału 0–100
```

Premia za towarzystwo wynosi 20, jeżeli w tym samym regionie jest co najmniej jeden inny osobnik tego gatunku w zasięgu `company_radius`. Kolejni towarzysze nie mnożą tej premii.

Sucha powierzchnia regionu jest dzielona przez liczbę stworków korzystających ze wspólnego regionu. Stres tłoku to brakująca część `preferred_area`, pomnożona przez `crowding_sensitivity`. Stworki trzymane przez gracza nie zajmują tej przestrzeni.

Stres hałasu to lokalne natężenie pomnożone przez `noise_sensitivity`. Hałas tworzą pracujące maszyny, ścinanie, wydobycie i uderzenia Pebblita. Słabnie z odległością i z upływem czasu. Płoty i granice regionów go nie tłumią. Stworek ignoruje własne źródła hałasu.

Niechęć do gatunków jest zapisana w `species_aversions`. Działa, jeśli dany gatunek występuje w tym samym regionie, niezależnie od odległości. Wagi obecnych nielubianych gatunków sumują się do maksymalnie 1. Większa liczba osobników tego samego obcego gatunku nie mnoży jego wagi.

Wrażliwości są cechami gatunku. Obie płcie korzystają z tych samych ustawień. To nie są obecnie indywidualnie losowane charaktery.

`happiness_response_seconds` określa tempo zmiany zadowolenia: `100 / happiness_response_seconds` punktów na sekundę. Przy wartości 30 różnica 10 punktów wyrównuje się w około 3 sekundy, a różnica pełnych 100 punktów w 30 sekund. Nie jest to sztywny czas oczekiwania na każdą zmianę.

Tempo wybranych prac wynosi od 70 procent przy zerowym zadowoleniu do 110 procent przy pełnym zadowoleniu. Nie ma statystyki energii.

### Wybieranie pracy i odpoczynek

Kontroler szuka miejsca w pobliżu, sprawdzając grunt, wodę, nachylenie, wolną przestrzeń, lokalny limit wytworzonych obiektów i możliwość dojścia. Dla zadań ekosystemowych wykonuje do 40 prób losowego wyboru miejsca w zasięgu `production_radius`.

Sadzenie, uderzenie lub tworzenie piasku jest związane z określonym momentem animacji. `_effect_done` zapobiega wielokrotnemu wykonaniu tego samego efektu w trakcie jednej pracy i pomaga zachować poprawny stan po wczytaniu gry.

Po pracy może wystąpić krótka przerwa `resting_seconds`. Niezależnie od niej, po losowo wybranej liczbie cykli od `leisure_cycles_min` do `leisure_cycles_max` stworek wybiera czas wolny. Trwa on od `leisure_seconds_min` do `leisure_seconds_max`, domyślnie 8–16 sekund po 1–2 cyklach. Odpoczynek ma własną animację. Napełnienie okolicy roślinami lub złożami może zatrzymać dalszą produkcję do czasu zwolnienia miejsca; nie jest to blokada głodu.

### Agresja Pebblita

Decyzja o rozpoczęciu nowego ataku ma dwa niezależne warunki:

- `happiness <= aggression_threshold`, domyślnie 40;
- albo dodatnia sucha powierzchnia na osobnika jest mniejsza niż `preferred_area × 0.5`.

Pebblit ma obecnie `preferred_area = 24`, więc mniej niż 12 metrów kwadratowych suchego terenu na osobnika może wywołać agresję nawet przy wyższym zadowoleniu. Podniesienie `aggression_threshold` powoduje łatwiejsze wywołanie agresji.

Nowa szarża wymaga suchego gruntu, gotowej nawigacji, zakończonego odpoczynku i dostępnego celu. Kontroler sprawdza budynki oraz drewniane płoty w zasięgu `production_radius + 2` metry i szuka najbliższego celu, do którego może podejść i uderzyć bez trafiania przez przeszkodę. Gdy nie ma celu, Pebblit może wybrać zwykłą pracę. Próby wyboru agresywnego celu są ograniczone odstępem około 0.8 sekundy.

Domyślne obrażenia `impact_damage` wynoszą 25. Każda ukończona szarża kończy się obowiązkowym odpoczynkiem `aggression_cooldown`, domyślnie 12 sekund. Po nim Pebblit sprawdza warunki ponownie. Jeśli nadal jest niezadowolony albo ma za ciasno, może znowu zaatakować. Jest to cykl szarży i odpoczynku, a nie zużywanie paska energii.

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

Nauka pochodzi z pierwszego poznania receptur oraz pierwszych zaobserwowanych działań gatunku, między innymi wyklucia, pracy i rozmnażania. Ponowne wykonanie tej samej obserwacji nie odnawia nagrody. Odkrycia budynków nie dają nauki.

Kolejne jaja z warsztatu zużywają surowce i naukę. Surowce mogą być odnawiane przez ekosystem, natomiast obecne nagrody nauki są związane z pierwszymi zdarzeniami. Ta różnica ogranicza masową produkcję jaj i wymaga dalszego balansu.

## Narzędzia projektu

Godot Database oraz przeglądarkowy World Studio korzystają ze wspólnych zasobów bazy. Zakładki Creatures, Discoveries i Database służą do zmiany danych. Design Doc służy do opisu decyzji. Zapis w jednym edytorze odświeża czysty widok drugiego. Niezapisane szkice nie są automatycznie zastępowane.

Interfejsy dodatku budujemy jako sceny Control i Container. Skrypty wiążą dane, widoczność i zdarzenia. Parametry silnika i przebieg AI mają czytelne nazwy, a techniczne pola nie są wystawiane w interfejsie gracza.

## Pomysły wymagające dalszych decyzji

- Docelowy długofalowy cel ekosystemu i zakończenie kolejnych etapów rozwoju.
- Dalszy balans nauki, kosztów jaj i cen rosnącej liczby budynków.
- Rury i połączenia pomiędzy maszynami. Same przyłącza w modelach nie oznaczają gotowej sieci przepływu.
- Zakres niszczenia w szale Pebblita poza obecnymi płotami i budynkami, na przykład rośliny i skały.
- Kolejne gatunki, zależności między nimi i bardziej rozbudowane środowiska.
