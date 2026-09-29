# RustingShader — шейдерпак для Minecraft (Iris)

Это руководство для тех, кто уже писал GLSL (вершинные, фрагментные, compute-шейдеры)
в своём движке, но ещё не писал шейдеры для Minecraft. Здесь объясняется,
чем Minecraft отличается от «своего движка», как устроен RustingShader и как его менять.

---

## 1. Главное отличие от своего движка

В своём движке (например, RustingEngine) ты сам решаешь всё: какие буферы создать,
какие draw call'ы сделать, в каком порядке идут проходы, какие uniform'ы передать.

В Minecraft всё это делает **Iris**. Ты не пишешь ни строчки на CPU. Ты только кладёшь
GLSL-файлы с **заранее известными именами**, а Iris:

- рисует мир как обычно, но подставляет твои шейдеры вместо ванильных;
- сам создаёт буферы (`colortex0..15`, `depthtex0/1`, `shadowtex0/1`);
- сам заполняет uniform'ы: ты просто объявляешь `uniform vec3 cameraPosition;`,
  и Iris по **имени** понимает, что туда положить;
- сам запускает полноэкранные проходы (`composite`, `final`) в нужном порядке.

То есть имя файла — это «точка входа», а имя uniform'а — это «API».

Ещё отличия:

| Свой движок | Iris / Minecraft |
|---|---|
| `#version 450`, `in`/`out`, `layout(location=…)` | `#version 120`: `attribute`, `varying`, `gl_FragData[i]` |
| `texture()` | `texture2D()` |
| `#include` нет, склеиваешь сам | Iris понимает `#include "/lib/x.glsl"` (путь от папки `shaders/`) |
| Настройки передаёшь uniform'ами | Настройки — это `#define`, Iris сам делает из них меню |
| Выход прохода — в какой хочешь attachment | Выходы задаются комментарием `/* DRAWBUFFERS:01 */` |

---

## 2. Конвейер кадра (порядок проходов)

```
shadow          мир рисуется с точки зрения солнца  -> shadowtex0 (карта теней)
   |
gbuffers_*      мир рисуется с камеры, по типам геометрии:
   |              terrain (блоки), water (вода/стекло), entities (мобы),
   |              hand (рука), clouds, textured (частицы), skybasic (небо/звёзды),
   |              skytextured (солнце/луна), basic (линии)...
   |            -> colortex0 (цвет), colortex1 (данные воды), depthtex0/1 (глубина)
   |
composite       полноэкранный проход: небо, облака, вода, туман, лучи
   |            -> colortex0
   |
final           полноэкранный: bloom, экспозиция, тонмаппинг, цветокор -> экран
```

Каждый проход — пара файлов: `.vsh` (вершинный) и `.fsh` (фрагментный).
Если какого-то `gbuffers_*` нет, Iris использует более общий (например, нет
`gbuffers_entities`, тогда берётся `gbuffers_textured_lit`, потом `gbuffers_textured`,
потом `gbuffers_basic`).

**Буферы RustingShader:**

| Буфер | Что лежит |
|---|---|
| `colortex0` | HDR-цвет сцены (RGBA16F, значения могут быть > 1) |
| `colortex1` | вода: `rgb` = нормаль волны в мировых координатах, `a` = skylight (0 = не вода) |
| `depthtex0` | глубина вместе с водой и стеклом |
| `depthtex1` | глубина только непрозрачных блоков (то, что под водой) |
| `shadowtex0` | карта теней |

Форматы задаются в `program/composite.fsh`, в блоке комментария `const int colortex0Format = RGBA16F;`.
Iris читает такие строки прямо из комментариев.

---

## 3. Структура файлов

```
RustingShader/
├── README.md            обзор для GitHub
├── docs/GUIDE.ru.md     этот файл
├── tools/
│   ├── check.py         проверка компиляции всех шейдеров без запуска игры
│   └── preview.py       рендер неба Энда в PNG (для быстрых экспериментов)
└── shaders/
    ├── shaders.properties   меню настроек, экраны, ползунки, blend-режимы
    ├── block.properties     ID для блоков (растения, вода, светящиеся блоки)
    ├── lang/en_US.lang      названия настроек в меню
    │
    ├── lib/                 общие функции (подключаются через #include)
    │   ├── settings.glsl    ВСЕ настройки (#define) — начинай отсюда
    │   ├── common.glsl      шум, волны воды, цвет неба, цвет солнца, северное сияние
    │   ├── shadow.glsl      мягкие тени (PCSS)
    │   ├── clouds.glsl      объёмные облака и их тени
    │   └── end.glsl         небо Энда: чёрная дыра, туманности, звёзды
    │
    ├── program/             НАСТОЯЩИЙ код проходов
    │   ├── lit.vsh / lit.fsh        вся геометрия мира (блоки, мобы, вода, рука...)
    │   ├── composite.vsh / .fsh     небо, облака, вода, туман, лучи
    │   ├── final.fsh                bloom, экспозиция, ACES, цветокор, блик
    │   ├── shadow.vsh / .fsh        карта теней
    │   └── gbuffers_sky*.vsh/.fsh   звёзды, луна
    │
    ├── gbuffers_*.vsh/.fsh, composite.*, final.*, shadow.*   ОБЁРТКИ (Обычный мир)
    ├── world-1/             те же обёртки для Незера (+ #define NO_SKY)
    └── world1/              те же обёртки для Энда  (+ #define NO_SKY, #define END)
```

### Обёртки

Почти все файлы в корне `shaders/` — это 3–5 строк:

```glsl
#version 120
/* DRAWBUFFERS:01 */
#define WATER
#include "/program/lit.fsh"
```

Весь код лежит в `program/`, а обёртка только включает нужные флаги.
Так один `lit.fsh` обслуживает блоки, воду, мобов и руку, а различаются они `#define`'ами:

| Флаг | Где | Что делает |
|---|---|---|
| `TERRAIN` | gbuffers_terrain | качание растений |
| `WATER` | gbuffers_water | вода не рисуется, а пишет нормаль в colortex1 |
| `ENTITIES` | gbuffers_entities | красная вспышка при уроне |
| `NO_SHADOW` | gbuffers_hand | рука без теней |
| `UNLIT` | textured, basic | без освещения |
| `NO_SKY` | world-1, world1 | нет неба, облаков, солнца |
| `END` | world1 | небо и освещение Энда |

**Важно:** `#version` и `/* DRAWBUFFERS */` должны быть в самой обёртке, а не в `program/`.

### Папки измерений

`world-1` — Незер, `world1` — Энд. **Iris берёт из такой папки полный набор
программ и не подставляет недостающие из корня.** Поэтому в каждой папке есть копия
каждой обёртки. Если добавляешь новую программу в корень, добавь её и в обе папки
(см. рецепт 7.6).

---

## 4. Рабочий цикл

1. Редактируешь файлы в `~/Rusting/RustingShader/shaders/`. Пак подключён в инстансы
   симлинком, копировать ничего не нужно.
2. Проверяешь компиляцию без игры:
   ```
   python3 ~/Rusting/RustingShader/tools/check.py
   ```
   Выводит `OK`/`ERR` по каждому файлу и текст ошибки (нужен `glslangValidator`, уже стоит).
3. В игре жмёшь **R**: Iris перезагружает шейдеры.
4. Если шейдер не собрался в игре, Iris напишет ошибку в чат. Полный текст смотри в логе:
   ```
   ~/.local/share/PrismLauncher/instances/MyMinecraft/minecraft/logs/latest.log
   ```
   Ищи строки со словами `shader`, `error`, `RustingShader`.
5. **F2** — скриншот, лежит в `.../MyMinecraft/minecraft/screenshots/`.

Для неба Энда есть быстрый предпросмотр без игры:
```
~/.venv-aurora/bin/python ~/Rusting/RustingShader/tools/preview.py out.png            # смотрим прямо на дыру
~/.venv-aurora/bin/python ~/Rusting/RustingShader/tools/preview.py out.png 0.6 0.1 80 # чуть в сторону, fov 80
```

---

## 5. Как работают настройки

В `lib/settings.glsl`:

```glsl
#define WATER_CLARITY 1.0 // [0.5 0.75 1.0 1.5 2.0]
#define WATER_CAUSTICS
//#define CINEMATIC_BARS
```

- `#define ИМЯ значение // [варианты]` — Iris сам делает из этого переключатель в меню.
- `#define ИМЯ` без значения — галочка «вкл». Закомментированный `//#define ИМЯ` — «выкл».
- В коде используешь как обычный макрос: `WATER_CLARITY` или `#ifdef WATER_CAUSTICS`.

Чтобы настройка появилась в меню:
1. `shaders.properties`: добавь имя в нужный `screen.XXX=...`, а если это ползунок,
   то ещё и в `sliders=...`.
2. `lang/en_US.lang`: строка `option.ИМЯ=Красивое название`.
   Для вариантов с числами можно подписать каждое значение: `value.END_STYLE.0=Empty`.

Смена настройки в меню пересобирает шейдеры. Значения хранятся в
`.../minecraft/shaderpacks/RustingShader.txt`.

---

## 6. Где что находится (куда смотреть, чтобы поменять X)

| Хочу поменять | Файл | Что искать |
|---|---|---|
| яркость солнца, луны, факелов | `lib/settings.glsl` | `SUN_STRENGTH`, `TORCH_*` |
| цвет солнечного света днём/на закате | `lib/common.glsl` | `directLightColor()` |
| цвет неба | `lib/common.glsl` | `skyColor()` |
| освещение блоков (ambient, свет, мокрые блоки) | `program/lit.fsh` | `main()`, после `#ifndef UNLIT` |
| мягкость/размер теней | `lib/shadow.glsl` | `getShadow()` |
| форму облаков | `lib/clouds.glsl` | `cloudDensity()` |
| волны воды | `lib/common.glsl` | `waterHeight()`, `waterNormal()` |
| цвет, прозрачность, отражения воды | `program/composite.fsh` | блок `if (wat.a > 0.0)` |
| туман, низкий туман, лучи света | `program/composite.fsh` | `// ---- fog ----` |
| подводные лучи | `program/composite.fsh` | `UNDERWATER_RAYS` |
| северное сияние | `lib/common.glsl` | `aurora()` |
| луна (фазы, кратеры, ореол) | `lib/common.glsl` | `moonColor()` |
| дождь и снег | `program/lit.fsh` | `#ifdef WEATHER` |
| чёрная дыра, туманности, звёзды Энда | `lib/end.glsl` | `diskGlow()`, `endSpace()`, `endSky()` |
| где на небе чёрная дыра | `lib/end.glsl` | `endHoleDir()` |
| дым в Энде | `program/composite.fsh` | `END_SMOKE` |
| освещение островов Энда | `program/lit.fsh` | `#ifdef END` |
| bloom, цветокоррекция, виньетка, блик | `program/final.fsh` | |
| какие блоки качаются / светятся | `block.properties` | |

---

## 7. Рецепты

### 7.1 Поменять цифру

Проще всего: открой `lib/settings.glsl`, поменяй значение по умолчанию, нажми R.
Если значения нет в списке `[...]`, добавь его в список, иначе меню будет путаться.

### 7.2 Новый ползунок

Хочу регулировать силу зерна плёнки.

`lib/settings.glsl`:
```glsl
#define FILM_GRAIN 0.0 // [0.0 0.02 0.04 0.08]
```
`shaders.properties`: добавь `FILM_GRAIN` в `screen.POST=...` и в `sliders=...`.
`lang/en_US.lang`: `option.FILM_GRAIN=Film Grain`.

И используй в коде (следующий рецепт).

### 7.3 Новый эффект постобработки

`program/final.fsh`, перед строкой с дизерингом (`color += (ign(...`):
```glsl
    // зерно плёнки: случайный шум, свой на каждый кадр
    color += (hash12(gl_FragCoord.xy + frameTimeCounter * 60.0) - 0.5) * FILM_GRAIN;
```
`hash12` и `frameTimeCounter` уже есть в `lib/common.glsl`, который подключён в `final.fsh`.

Здесь `color` уже после тонмаппинга (0..1). Если нужен эффект в HDR (до тонмаппинга),
вставляй его выше, до `color = aces(...)`.

### 7.4 Эффект в мире (composite)

В `program/composite.fsh`, в `main()`, у тебя уже есть всё нужное для пикселя:

| Переменная | Что это |
|---|---|
| `color` | текущий цвет пикселя (HDR, линейный) |
| `dir` | направление взгляда в мировых координатах (нормализованное) |
| `dist` | расстояние до поверхности в блоках |
| `d0` | глубина (`1.0` = небо) |
| `pp0` | позиция относительно камеры, `pp0 + cameraPosition` = мировая позиция |
| `sunDir`, `sunLight` | направление и цвет солнца |
| `under` | камера под водой |

Пример: красноватый туман ниже высоты 30 (как будто пещеры светятся):
```glsl
    vec3 wp = pp0 + cameraPosition;
    if (d0 < 1.0 && wp.y < 30.0)
        color = mix(color, vec3(0.3, 0.05, 0.02), smoothstep(30.0, 0.0, wp.y) * 0.3);
```

### 7.5 Новый светящийся (или качающийся) блок

1. `block.properties`: добавь имя блока в нужную строку. Имена как в игре, без `minecraft:`,
   можно с состоянием: `furnace:lit=true`.
   - `10005` светятся самые яркие пиксели (огонь, лампы, светокамень)
   - `10006` светятся красные пиксели (редстоун; пыль тем ярче, чем больше сигнал)
   - `10007` светятся яркие насыщенные пиксели (кристаллы, скалк, портал)
   - `10008` светится тёплый огонь внутри блока (печи, свечи)
   - `10009` лава и магма (ореол слабее, чтобы Незер не утонул в дымке)
   - `10010` руды (опция `GLOWING_ORES`)
   - `10001`/`10002`/`10004` качаются (растения, листва, высокие растения)
2. Всё. Мобы и предметы в руке так же: `entity.properties` и `item.properties`, те же номера.

Как это устроено: `emission()` в `program/lit.fsh` по ID выбирает маску пикселей и возвращает
свечение. Оно прибавляется к цвету и пишется в `colortex2`. `composite1.fsh` размывает `colortex2`
гауссом в 8 размерах (плитки в `colortex3`), `final.fsh` складывает их в ореол (`GLOW_STRENGTH`).
Код ореола: `lib/glow.glsl`, проверка без игры: `tools/glowtest.py`. Писать в `colortex2` могут только
программы с `/* DRAWBUFFERS:02 */` и `#define EMISSIVE_OUT` в обёртке.

Для **нового** ID, например `10012` для своей маски:
```
block.10012=amethyst_cluster large_amethyst_bud
```
и в `emission()` в `program/lit.fsh`:
```glsl
    if (id == 10012.0) return color * vec3(0.8, 0.4, 1.0) * 0.5;
```
Сравнивай только `id` (округлённый), не `blockId` напрямую: см. раздел 8.

### 7.6 Новая программа

Например, хочу свой шейдер для дождя/снега: `gbuffers_weather`.

1. Код в `program/weather.fsh` (и `.vsh`), без `#version`.
2. Обёртка в корне `shaders/gbuffers_weather.fsh`:
   ```glsl
   #version 120
   /* DRAWBUFFERS:0 */
   #include "/program/weather.fsh"
   ```
3. Копии для измерений. Скрипт делает то же, что было сделано при создании пака:
   ```fish
   cd ~/Rusting/RustingShader/shaders
   for f in gbuffers_weather.vsh gbuffers_weather.fsh
       sed '1a #define NO_SKY' $f > world-1/$f
       sed '1a #define NO_SKY\n#define END' $f > world1/$f
   end
   ```
4. `python3 ~/Rusting/RustingShader/tools/check.py`, потом R в игре.

### 7.7 Поменять что-то только в одном измерении

Используй флаги:
```glsl
#ifdef END
    ...только Энд...
#elif defined NO_SKY
    ...только Незер...
#else
    ...обычный мир...
#endif
```

### 7.8 Новый uniform от Iris

Просто объяви его в файле, где он нужен, и Iris его заполнит:
```glsl
uniform float nightVision;   // 0..1, действует ли ночное зрение
uniform int   worldTime;     // время суток 0..23999
uniform float playerMood;    // «настроение» пещеры 0..1
```
Полный список: <https://shaders.properties/current/reference/uniforms/overview/>.

**Нельзя объявлять дважды.** `lib/common.glsl` уже объявляет `gbufferModelViewInverse`,
`sunPosition`, `rainStrength`, `frameTimeCounter`. Там, где подключён `common.glsl`,
их не объявляй. Иначе будет ошибка `redefinition`.

---

## 8. Подводные камни

- **ID блоков и `varying`.** `blockId` приходит из вершинного шейдера через `varying`
  и интерполируется: `10003.0` может стать `10002.998`. Поэтому в `lit.fsh` есть
  `float id = floor(blockId + 0.5);` и сравнивается только `id`.
- **NaN.** `normalize(vec3(0))` даёт NaN, и пиксель (а через bloom и весь экран) становится
  чёрным или белым. В измерениях без солнца `sunPosition` может быть нулём, поэтому
  в `sunDirWorld()` добавлен крошечный сдвиг. Будь осторожен с `pow(x, y)` при `x < 0`,
  `sqrt(отрицательное)`, делением на ноль.
- **HDR и линейный цвет.** Всё до `final.fsh` — линейный HDR (яркость может быть 5, 20, 100).
  Текстуры Minecraft в sRGB, поэтому их переводят `toLinear()`. Гамма и ACES применяются
  только в `final.fsh`.
- **Производительность.** Composite выполняется для каждого пикселя экрана. Цикл на
  16 шагов с шумом внутри — это 16 × (пиксели экрана) вызовов. Облака, туман и лучи — это
  именно такие циклы, их число шагов в настройках (`CLOUD_STEPS`, `VL_STEPS`).
- **`#version 120`.** Нет `in/out`, `texture()`, `layout`, битовых операций, `uint`.
  Циклы лучше с константной границей: `for (int i = 0; i < 16; i++)`.
- **Системы координат.** `viewPos` — относительно камеры и её поворота (view space).
  `playerPos` — относительно камеры, но оси мировые. `worldPos = playerPos + cameraPosition`.
  Перевод view → player: `mat3(gbufferModelViewInverse) * v` (для направлений) или
  `(gbufferModelViewInverse * vec4(v, 1.0)).xyz` (для точек).

---

## 9. Как устроены главные эффекты (коротко)

- **Тени (PCSS).** `lib/shadow.glsl`: сначала ищем, насколько далеко от поверхности
  блокирующий объект. Чем дальше, тем шире размытие. Поэтому тень у ствола дерева резкая,
  а у кроны мягкая.
- **Вода.** В `gbuffers_water` вода не рисуется, а только записывает нормаль волны в
  `colortex1`. В `composite` для этих пикселей: преломление (сдвиг UV по нормали),
  поглощение света с глубиной, SSR (ищем отражение шагами по depth-буферу),
  блики солнца (GGX), пена у берега, каустика, окно Снелла снизу.
- **Облака.** Raymarch по слою высот; форма — 2D-карта погоды + 3D-шум для эрозии краёв;
  свет — Beer–Lambert + фазовая функция Хеньи–Гринстейна (яркий край у солнца).
- **Лучи (volumetric light).** Шагаем от камеры до пикселя и считаем, сколько точек
  освещено по карте теней.
- **Чёрная дыра.** `lib/end.glsl`: направление взгляда отклоняется около дыры
  (гравитационное линзирование, `a - rE²/a`), внутри радиуса — чёрный цвет. Диск —
  шум в полярных координатах, внутренние части вращаются быстрее (закон Кеплера).
  Дальняя сторона диска рисуется как кольцо вокруг дыры (эффект «Интерстеллара»).
  Эффект Доплера делает одну сторону ярче.
- **Bloom.** Iris строит mipmap'ы `colortex0` (`colortex0MipmapEnabled = true`),
  и `final.fsh` смешивает несколько размытых уровней.

---

## 10. Полезные ссылки

- Документация Iris и формата шейдерпаков: <https://shaders.properties/>
- Список uniform'ов: <https://shaders.properties/current/reference/uniforms/overview/>
- Имена программ и порядок проходов: <https://shaders.properties/current/reference/programs/overview/>
- Исходники других паков для вдохновения: Complementary, BSL, Photon (на GitHub / Modrinth).
