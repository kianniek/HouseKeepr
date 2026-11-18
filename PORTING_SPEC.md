# OpenGym → Flutter (`health_keepr` / `open_gym`) Porting Specification & Gap Analysis

## Overview & Sources Analyzed

This specification documents the complete gap analysis between:
1. **Original Reference Codebase:** [openGym v1.4.5](file:///c:/Users/kiann/Documents/CodingProjects/HouseKeepr/assets/OpenGymOriginalApp_NotFlutterYet/open_gym/openGym) (`frontend/src/views/`, `frontend/src/components/`, `frontend/src/store/`, `frontend/src/lib/`, `frontend/src/sheets.jsx`).
2. **Target UI & User Flow Screenshots (61 Reference Screens):**
   - Root screens in [OpenGym](file:///c:/Users/kiann/Documents/CodingProjects/HouseKeepr/assets/HealthKeeprDesign/OpenGym) (`home.png`, `plan_schedule.png`, `plan_routines.png`, `active_workout.png`, `stats_overview.png`, `stats_body.png`, `stats_lifts.png`, `stats_effort.png`, `exercises_list_1.png`, `exercises_list_2.png`, `exercises_filters.png`, `explore_muscles.png`, `explore_muscles_selected.png`, `skill_ladders_1.png`–`skill_ladders_7.png`).
   - Plan & Routine Edit user flows in [OpenGym/Plan](file:///c:/Users/kiann/Documents/CodingProjects/HouseKeepr/assets/HealthKeeprDesign/OpenGym/Plan) (21 screenshots covering Schedule Rotation mode, Loop editing, Add-to-rotation sheet, Swipe-to-remove from loop, Rotation-to-Fixed-Week confirmation dialog, Plan options share/import sheet, Routines view, Routines Edit mode, Swipe-to-delete/duplicate with Undo toast, and the full Routine Edit flow including icon picker, star toggle, progression policy sheet, folder sheet, routine type sheet, deload toggle, and add-exercise sheet).
   - Active Workout & Exercise Menu user flows in [OpenGym/GymSessionStart](file:///c:/Users/kiann/Documents/CodingProjects/HouseKeepr/assets/HealthKeeprDesign/OpenGym/GymSessionStart) (15 screenshots) and [OpenGym/GymExerciseEdit](file:///c:/Users/kiann/Documents/CodingProjects/HouseKeepr/assets/HealthKeeprDesign/OpenGym/GymExerciseEdit) (5 screenshots).
3. **Target Flutter Codebase:**
   - Umbrella module hub & local-first storage package: [packages/health_keepr](file:///c:/Users/kiann/Documents/CodingProjects/HouseKeepr/packages/health_keepr)
   - Feature implementation package loaded by `health_keepr`: [packages/open_gym](file:///c:/Users/kiann/Documents/CodingProjects/HouseKeepr/packages/open_gym)

---

## 1. Implementation Audit (Done vs. Missing)

### Summary Matrix

| Area / Screen / Feature | Reference Source (`frontend/src/`) & Screenshots | Flutter Target (`packages/`) | Status |
| :--- | :--- | :--- | :--- |
| **HealthKeepr Hub & Deferred Loader** | Host integration | `health_keepr/lib/src/hub/health_keepr_hub_screen.dart`, `open_gym_launcher.dart` | **Complete** |
| **Local-First Hive Storage Engine** | `store/useStore.js`, `lib/state-json.js` | `health_keepr/lib/src/storage/local_health_data_store.dart` | **Complete** |
| **5-Tab Bottom Navigation Bar & Center Start/Resume Button** | `components/TabBar.jsx`, `home.png`, `plan_routines.png` | `open_gym/lib/src/ui/open_gym_dashboard_screen.dart` | **Partially Implemented** |
| **Home Tab (`/home`)** | `views/Home.jsx`, `home.png` | `open_gym_dashboard_screen.dart` (`_HomeTab`) | **Partially Implemented** |
| **Plan Tab — Header & Plan Options Sheet** | `views/Plan.jsx`, `Plan/plan_routines_share_sheet.png` | `open_gym_dashboard_screen.dart` (`_PlanTab`) | **Not Started** |
| **Plan Tab — Schedule View (Fixed Week)** | `views/Plan.jsx`, `plan_schedule.png`, `sheets.jsx` (`dayAssignSheet`) | `open_gym_dashboard_screen.dart` (`_PlanTab`), `programmes_screen.dart` | **Partially Implemented** |
| **Plan Tab — Schedule View (Rotation Loop & Edit/Add/Swipe)** | `views/Plan.jsx`, `lib/rotation.js`, `Plan/plan_schedule_rotation*.png` | `open_gym_dashboard_screen.dart` (`_PlanTab`), `open_gym_controller.dart` | **Partially Implemented** |
| **Plan Tab — Routines View (Folders, Favourites, Edit Mode, Swipe Delete/Duplicate + Undo)** | `views/Plan.jsx`, `lib/routine-folders.js`, `lib/routine-favs.js`, `Plan/plan_routines*.png` | `open_gym_dashboard_screen.dart` (`_PlanTab`) | **Partially Implemented** |
| **Routine Edit Screen (`/plan/r/:id`)** | `views/RoutineEdit.jsx`, `Plan/plan_routines_new_routine*.png` | `open_gym/lib/src/ui/routine_builder_screen.dart` | **Partially Implemented** |
| **Exercise Slot Configuration Sheet (`ExConfig`)** | `sheets.jsx` (`exConfigSheet`), `components/WarmupConfig.jsx`, `Tempo.jsx` | `routine_builder_screen.dart` (`_StepperField`), `exercise_menu_sheet.dart` | **Partially Implemented** |
| **Multi-Week Programmes (`/plan/programmes`)** | `views/Programmes.jsx`, `lib/programmes.js` | `open_gym/lib/src/ui/programmes_screen.dart`, `models/programme.dart` | **Partially Implemented** |
| **Active Workout Screen (`/workout`)** | `views/Workout.jsx`, `views/FocusView.jsx`, `GymSessionStart/*.png`, `GymExerciseEdit/*.png` | `open_gym/lib/src/ui/active_workout_screen.dart` | **Partially Implemented** |
| **Active Workout Menus & Session Sheets** | `sheets.jsx`, `components/WorkoutSettingsSheet.jsx`, `DurationWheel.jsx` | `open_gym/lib/src/ui/widgets/workout_session_sheets.dart`, `exercise_menu_sheet.dart` | **Partially Implemented** |
| **Circuit / AMRAP / EMOM / Intervals / Run-Walk Player** | `components/CircuitCard.jsx`, `CircuitPlayer.jsx`, `lib/circuit.js`, `store/useCircuit.js` | — | **Not Started** |
| **Timed-Set Hold Timer, Overtime & Auto-Holds Count-In** | `components/RestTimer.jsx`, `store/useUI.js`, `lib/auto-holds.js` | — | **Not Started** |
| **Stats Tab — Overview Section** | `views/Stats.jsx`, `stats_overview.png` | `open_gym/lib/src/ui/stats_screen.dart` (`_buildOverview`) | **Partially Implemented** |
| **Stats Tab — Body Section** | `views/Stats.jsx`, `stats_body.png` | `open_gym/lib/src/ui/stats_screen.dart` (`_buildBody`) | **Partially Implemented** |
| **Stats Tab — Lifts & Muscles Section** | `views/Stats.jsx`, `components/WeeklySets.jsx`, `StrengthLevel.jsx`, `stats_lifts.png` | `open_gym/lib/src/ui/stats_screen.dart` (`_buildLifts`) | **Partially Implemented** |
| **Stats Tab — Effort Section** | `views/Stats.jsx`, `lib/effort.js`, `stats_effort.png` | `open_gym/lib/src/ui/stats_screen.dart` (`_buildEffort`) | **Partially Implemented** |
| **Exercise Library Tab (`/library`)** | `views/Library.jsx`, `exercises_list_1.png`, `exercises_list_2.png`, `exercises_filters.png` | `open_gym/lib/src/ui/exercise_library_screen.dart` | **Partially Implemented** |
| **Explore Muscles Screen (`/muscles`)** | `views/Muscles.jsx`, `components/MuscleExplorer.jsx`, `explore_muscles*.png` | `open_gym/lib/src/ui/explore_muscles_screen.dart`, `widgets/body_map_widget.dart` | **Partially Implemented** |
| **Skill Ladders Sheet (`Ladders.jsx`)** | `components/Ladders.jsx`, `lib/ladders.js`, `skill_ladders_1.png`–`7.png` | `open_gym/lib/src/ui/skill_ladders_sheet.dart` | **Partially Implemented** |
| **Measurements & Weigh-Ins (`/measurements`)** | `views/Measurements.jsx`, `sheets.jsx` (`weighInsSheet`, `bwSheet`) | `open_gym/lib/src/ui/measurements_screen.dart` | **Partially Implemented** |
| **Progress Photos (`/progress-photos`)** | `views/ProgressPhotos.jsx`, `components/PhotoCompare.jsx` | `open_gym/lib/src/ui/progress_photos_screen.dart` | **Partially Implemented** |
| **Tools & Calculators (`/tools`)** | `views/Tools.jsx`, `lib/calculators.js`, `lib/onerm.js` | `open_gym/lib/src/ui/tools_screen.dart` | **Partially Implemented** |
| **Workout History (`/history`)** | `views/History.jsx`, `sheets.jsx` (`workoutDetailSheet`, `logPastWorkoutSheet`) | `open_gym/lib/src/ui/workout_history_screen.dart` | **Partially Implemented** |
| **Structural Balance (`/structural-balance`)** | `views/StructuralBalance.jsx`, `lib/structuralBalance.js` | — | **Not Started** |
| **Unified Journal (`/journal`)** | `views/Journal.jsx`, `lib/journal.js` | — | **Not Started** |
| **Gym Check-In QR/Barcode Card (`/checkin`)** | `views/CheckIn.jsx`, `home.png` (`AT THE GYM / Check in`) | — | **Not Started** |
| **Sound Synthesizer & Haptics Engine** | `lib/sound.js`, `lib/rest-sounds.js` | `open_gym/lib/src/audio/wav_synthesizer.dart`, `open_gym_sound_service.dart` | **Complete** |
| **Self-Hosted Server Sync, WebDAV & Health Connect** | `lib/api.js`, `components/WebDavBackup.jsx`, `lib/health-sync.js` | `open_gym/lib/src/sync/*`, `server_connect_screen.dart`, `health_connect_settings_screen.dart` | **Complete** |

---

### Detailed Audit by Feature & Screen

#### 1.1 HealthKeepr Hub, Deferred Launcher & Local Storage (`packages/health_keepr`) — **Complete**
- [health_keepr_hub_screen.dart](file:///c:/Users/kiann/Documents/CodingProjects/HouseKeepr/packages/health_keepr/lib/src/hub/health_keepr_hub_screen.dart), [open_gym_launcher.dart](file:///c:/Users/kiann/Documents/CodingProjects/HouseKeepr/packages/health_keepr/lib/src/registry/open_gym_launcher.dart), and [local_health_data_store.dart](file:///c:/Users/kiann/Documents/CodingProjects/HouseKeepr/packages/health_keepr/lib/src/storage/local_health_data_store.dart) cleanly implement the local-first Hive JSON storage contract (`HealthDataStore`), module isolation, and deferred loading (`OpenGymInstallDialog`).

#### 1.2 Dashboard Shell & Navigation Bar (`open_gym_dashboard_screen.dart`) — **Partially Implemented**
- **What is done:** 5-item bottom bar (`Home`, `Plan`, `Start`/`Active`, `Stats`, `Exercises`), long-press on center button opens workout picker sheet, active workout persistent bottom sheet banner.
- **Exact bugs / missing behaviors:**
  1. **Duplicate/Unwanted Top `AppBar` on Plan, Stats, and Exercises Tabs ([open_gym_dashboard_screen.dart:111-133](file:///c:/Users/kiann/Documents/CodingProjects/HouseKeepr/packages/open_gym/lib/src/ui/open_gym_dashboard_screen.dart#L111-L133)):** When `_tabIndex != 0`, `OpenGymDashboardScreen` renders an `AppBar` titled `'OpenGym'` above `_PlanTab`, `StatsScreen`, and `ExerciseLibraryScreen`. In the reference app and all screenshots (`plan_schedule.png`, `plan_routines.png`, `stats_overview.png`, `exercises_list_1.png`), there is no top `'OpenGym'` AppBar on tabs 1–3; each tab starts directly with its own large header (`Plan`, `Stats`, `Exercises`).
  2. **Floating Action Button on Plan Tab ([open_gym_dashboard_screen.dart:204-215](file:///c:/Users/kiann/Documents/CodingProjects/HouseKeepr/packages/open_gym/lib/src/ui/open_gym_dashboard_screen.dart#L204-L215)):** Renders a `FloatingActionButton.extended` (`'New routine'`) across the entire Plan tab (including on the `Schedule` view), whereas in `Plan.jsx` and `Plan/plan_routines.png` there is no FAB—`+ New routine` is an inline tonal pill button in the `Routines` action bar, and `+ Add` is an inline tonal pill button in `The loop` header on `Schedule`.
  3. **Center Button Active Elapsed Timer:** In `TabBar.jsx`, when a workout is active in the background, the center button shows a live elapsed timer (`<Elapsed />`) and pulsing recording dot instead of a static `'Active'` label + bottom sheet banner.

#### 1.3 Home Tab (`_HomeTab` in `open_gym_dashboard_screen.dart`) — **Partially Implemented**
- **What is done:** Header with date and settings button, Rotation/Weekly Plan card with `'Up next'` chip and `'Choose a different workout'` button, Body weight card with quick-log dialog and `OpenGymLineChart`.
- **Exact bugs / missing behaviors:**
  1. **Missing 7-Day Interactive Week Strip (`Home.jsx`, `home.png`):** In `home.png`, the top card in Fixed Week mode shows `< This week >` with a 7-day horizontal strip (`Mon 13`..`Sun 19` with green completed dots and blue planned dots), followed by the `Today` row showing routine name (`Push Day`), compact `BodyMapWidget`, and a lime `Start` pill button. Tapping any day in the strip opens `dayOverrideSheet(iso)` to view/change that date's workout, log a missed workout, or add a day note (`Sick`, `Injury`, `Travel`, `Busy`, `Rest day`).
  2. **Missing Gym Check-In Card (`home.png`):** Missing the `AT THE GYM` / `Check in` card (with QR code icon) that opens the gym membership barcode/QR card viewer.
  3. **Missing Body Weight Delta, Weekly Rate & Goal Pill (`home.png`):** The `Body weight` card in `home.png` displays the latest change badge (`▼ 0.2`), date (`13 Apr`), `Goal 78 kg · 3 kg to lose`, 30-day trend line + dashed goal line, `Weekly change −0.28 kg / week · −0.35%/wk`, and an interactive `78` goal button (opening `GoalSheet`) next to `All weigh-ins >`. Flutter's `_HomeTab` ([open_gym_dashboard_screen.dart:587-633](file:///c:/Users/kiann/Documents/CodingProjects/HouseKeepr/packages/open_gym/lib/src/ui/open_gym_dashboard_screen.dart#L587-L633)) lacks the delta badge, weekly rate calculation (`lib/bodyweight.js`), and interactive goal button.
  4. **Missing Weekly Streak Card (`home.png`):** Missing the bottom `2 week streak` card (`1 / 3 this week · 7 workouts total`, `Best 2w · 2w to next freeze`).

#### 1.4 Plan Tab — Schedule View (`_PlanTab` in `open_gym_dashboard_screen.dart`) — **Partially Implemented**
- **What is done:** Header (`Plan`), `Schedule` / `Routines` segmented control, `How you train` card (`Fixed Week` / `Rotation`), basic rotation list of `controller.templates` with `Start the loop over`.
- **Exact bugs / missing behaviors (comparing against `Plan.jsx` and `Plan/plan_schedule_*.png`):**
  1. **Missing Top-Right Plan Options Share/Menu Button & Sheet (`Plan.jsx:161-176`, `Plan/plan_routines_share_sheet.png`):** Top-right of the `Plan` header must have a circular share/options button opening the `Plan` modal bottom sheet with 7 items:
     - `Export plan file` (*"A small file a friend can import into their own openGym. Routines only, none of your workouts or weigh-ins."*)
     - `Print / Save as PDF`
     - `Import a plan file`
     - `Scan a QR code` (*"A routine from a friend’s phone, the website or the poster by the squat rack."*)
     - `Load starter plan` (opens Starter Plan sheet)
     - `Routine from a past workout` (builds a template from a past `WorkoutLog`)
     - `Programmes` (*"Your routines as a block of weeks, with starter programmes to try."*)
  2. **Missing Explanatory Footer Under `How you train` Card (`Plan.jsx:322-324`, `Plan/plan_schedule_rotation.png`):**
     - When `Rotation`: *"Routines in a loop. Whatever is next stays next until you train it, whatever the day."*
     - When `Fixed Week`: *"The same routines on the same weekdays, every week."*
  3. **Missing Confirmation Modal When Switching from Active Rotation to Fixed Week (`Plan.jsx:242-252`, `Plan/plan_schedule_rotation_to_fixed_week_dialog.png`):**
     - Switching from `Rotation` to `Fixed Week` while a rotation loop is active must prompt a centered dialog:
       - Title: **`Back to a fixed week?`**
       - Message: *"The loop stops. Your weekdays stay as they are, and the loop is saved for later."*
       - Primary lime button: **`Use Fixed Week`**
       - Secondary text button: **`Cancel`**
  4. **Rotation Sequence Model Doesn't Support `Rest day` Stops or Duplicate Routine Stops (`lib/rotation.js`, `Plan/plan_schedule_rotation.png`):**
     - In Flutter ([open_gym_dashboard_screen.dart:789-823](file:///c:/Users/kiann/Documents/CodingProjects/HouseKeepr/packages/open_gym/lib/src/ui/open_gym_dashboard_screen.dart#L789-L823)), `The loop` simply iterates over `controller.templates`, so the user cannot have `Rest day` stops in the loop, cannot include a routine twice (`A → Rest → B → Rest → C`), and cannot remove a routine from the loop without deleting the routine itself.
     - In `Plan.jsx` and `Plan/plan_schedule_rotation.png`, the rotation loop is an independent ordered sequence of stop IDs (`List<String> rotationSequence`, where `'rest'` represents a **Rest day** stop with moon icon and subtitle *"A day off before the next one"*, and routine IDs have their lime rounded-square glyph badge).
  5. **Missing `Edit` Mode & `+ Add` Sheet on `The loop` (`Plan.jsx:269-277, 357-399`, `Plan/plan_schedule_rotation_edit.png`, `Plan/plan_schedule_rotation_edit_add_sheet.png`):**
     - The header row for `The loop` must have `Edit` (toggles to `Done`) and a tonal `+ Add` button on the right (instead of `Start the loop over`, which belongs below the loop list!).
     - Tapping `+ Add` opens the **`Add to the rotation`** bottom sheet (`plan_schedule_rotation_edit_add_sheet.png`) listing **`Rest day`** (*"A day off before the next one"*) followed by every routine (with subtitle *"Already in the loop: adds it again"* if already present in `rotationSequence`).
     - Tapping `Edit` enters loop edit mode (`plan_schedule_rotation_edit.png`): each row shows a red circular `−` button on the left to remove that stop from the loop, hides the mini body map, and shows a `⇅` drag handle on the right to reorder stops.
  6. **Missing Swipe-Left to Remove Stop from `The loop` with Undo Toast (`Plan.jsx:78-134, 394-397`, `Plan/plan_schedule_rotation_swipe_remove.png`):**
     - Swiping any stop row left in `The loop` reveals a red `− Remove` action button and triggers `takeOutOfLoop` with toast `"“<Name>” is out of the loop."` and an `Undo` action.
  7. **Missing Loop Round Progress Footer & Bottom `Start the loop over` Button (`Plan.jsx:400-413`, `Plan/plan_schedule_rotation.png`):**
     - Below `The loop` list, displays `"<done> of <total> done this round. Trained out of order? Just pick another routine on Home."` (or in Edit mode: `"<done> of <total> done this round. Drag to reorder. Tap the minus to take one out."`), followed by the `↺ Start the loop over` button below it.
  8. **Fixed Week Mode Pushes Separate Screen Instead of Rendering Inline 7-Day Schedule (`Plan.jsx:352-355`, `plan_schedule.png`):**
     - In Flutter ([open_gym_dashboard_screen.dart:765-775](file:///c:/Users/kiann/Documents/CodingProjects/HouseKeepr/packages/open_gym/lib/src/ui/open_gym_dashboard_screen.dart#L765-L775)), Fixed Week mode only renders an `OutlinedButton` (`'Configure Weekly Schedule'`) that pushes `ProgrammesScreen`.
     - In `Plan.jsx` and `plan_schedule.png`, Fixed Week mode directly renders the 7 weekdays (`Monday`–`Sunday`) inline under `"This week"`, each showing weekday name, routine glyph (or moon icon for `Rest day`), routine title(s), exercise count, compact `BodyMapWidget`, and `>` chevron. Tapping a weekday opens `dayAssignSheet` (multi-select routines for that day + `"Train them: Together | Separately"` toggle + `"Rest day"`).
  9. **Missing `Weekly muscle volume` Link Card & `Load a starter plan` Footer (`Plan.jsx:426-429`, `plan_schedule.png`):**
     - Missing the bottom section cards on `Schedule` (`Programmes`, `Weekly muscle volume` linking to Stats, and `Load a starter plan`).

#### 1.5 Plan Tab — Routines View (`_PlanTab` in `open_gym_dashboard_screen.dart`) — **Partially Implemented**
- **What is done:** Lists `controller.templates` with title, exercise count, compact `BodyMapWidget`, and chevron; tapping opens `RoutineBuilderScreen`.
- **Exact bugs / missing behaviors (comparing against `Plan.jsx:435-536` and `Plan/plan_routines*.png`):**
  1. **Missing Action Bar (`Edit` / `Done` + Tonal `+ New routine` Button) (`Plan/plan_routines.png`, `Plan/plan_routines_edit.png`):**
     - Above the routines list, there must be a row with `Edit` (left, toggles to `Done`) and a tonal `+ New routine` pill button (right), with no floating action button.
  2. **Missing Routine Edit Mode (Delete Minus + Drag Reorder) (`Plan/plan_routines_edit.png`):**
     - When `Edit` is active, each routine card shows a red circular `−` delete button on the left, the lime rounded-square glyph badge, title & subtitle, and a `⇅` drag handle on the right (hiding the mini body map and chevron) to reorder routines globally.
  3. **Missing Swipe-Left to Delete & Swipe-Right to Duplicate with Undo Toasts (`Plan/plan_routines_swipe_delete.png`, `Plan/plan_routines_swipe_duplicate.png`):**
     - Swiping a routine card left reveals a red `🗑 Delete` action; triggering it removes the routine and shows toast `"“<Name>” gone."` with `↺ Undo` (restoring the routine, its list index, its weekday assignments, and its rotation loop positions).
     - Swiping a routine card right reveals a lime `❐ Duplicate` action; triggering it inserts `"<Name> (Copy)"` immediately below the original in the list (without navigating away) and shows toast `"Copied as “<Name> (Copy)”."` with `↺ Undo`.
  4. **Missing Routine Glyph Icons, Assigned Weekday Abbreviations in Subtitle, and Conditional Mini Body Map (`Plan/plan_routines.png`, `Plan/plan_routines_swipe_delete.png`):**
     - Each routine card must show its custom glyph icon inside a lime rounded square (`borderRadius: 12`), subtitle `<N> exercises · <Mo, We...>` (omitting the dot and days when not assigned to any weekday), and must **hide** `BodyMapWidget` when `entries.isEmpty` (`0 exercises`).
  5. **Missing Starred `Favourites` Section & Collapsible `Folder` Sections (`Plan.jsx:496-528`):**
     - Starred routines (`isFavorite == true`) must float to the top under a `★ Favourites` section header (and show a gold star icon next to their title).
     - Non-starred routines with a non-empty `folder` must group under collapsible folder headers (`📁 <Folder Name> <count> >`), where `"Archive"` defaults to collapsed.
  6. **Missing Footer Helper Caption (`Plan/plan_routines.png`, `Plan/plan_routines_edit.png`):**
     - Below the routine list: `"Tap a routine to edit it. Reorder and delete are behind Edit."` (or `"Drag to reorder. Tap the minus to delete."` in Edit mode).

#### 1.6 Routine Edit Screen (`routine_builder_screen.dart` vs `views/RoutineEdit.jsx` & `Plan/plan_routines_new_routine*.png`) — **Partially Implemented**
- **What is done:** Basic form with `Routine Name` `TextField`, `Goal` dropdown, `Description` `TextField`, `Add Exercise` button, and `ReorderableListView` with inline `Sets`, `Reps`, `Rest (s)` steppers and a top-right `Save` button.
- **Exact bugs / missing behaviors (comparing against `RoutineEdit.jsx` and `Plan/plan_routines_new_routine*.png`):**
  1. **Creation & Auto-Save Lifecycle Mismatch (`Plan.jsx:208-212`, `RoutineEdit.jsx:378-381`, `Plan/plan_routines_new_routine.png`):**
     - In the reference app and screenshots, tapping `+ New routine` immediately creates and persists a `WorkoutTemplate` named `"New routine"` with `0 exercises` and opens `RoutineEdit`. Every change (name, star, icon, progression, folder, routine type, deload toggle, exercises) persists immediately without a manual `Save` button, and a routine with `0 exercises` is completely valid (see `Plan/plan_routines_swipe_delete.png` showing `New routine / 0 exercises` and `New routine (Copy) / 0 exercises` in the Routines list!).
     - In Flutter ([routine_builder_screen.dart:70-83](file:///c:/Users/kiann/Documents/CodingProjects/HouseKeepr/packages/open_gym/lib/src/ui/routine_builder_screen.dart#L70-L83)), changes are only saved when tapping `Save`, and `_save()` blocks with `'Add at least one exercise.'` if `_entries.isEmpty`.
  2. **Header Layout: Inline Name Box, Star Button & Icon Picker Button (`RoutineEdit.jsx:501-513`, `Plan/plan_routines_new_routine.png`, `Plan/plan_routines_new_routine_copy_starred.png`, `Plan/plan_routines_new_routine_copy_icon_sheet.png`):**
     - Header must have:
       - Circular `<` back button.
       - Filled rounded text field for the routine name (`New routine`).
       - Circular **Star** button (`☆` / gold `★`) that toggles `isFavorite` and shows toast `"Starred. It leads your routines now."` (or `"No longer a favourite."`).
       - Circular **Icon** button showing the routine's current glyph; tapping opens the **`Pick an icon`** bottom sheet (`plan_routines_new_routine_copy_icon_sheet.png`) with 20 icons across 4 sections (`Strength`, `Equipment`, `Cardio`, `Recovery`) in a 5-column grid.
  3. **Missing 4-Row Grouped Routine Settings Card & Dynamic Footer (`RoutineEdit.jsx:515-542`, `Plan/plan_routines_new_routine.png`, `Plan/plan_routines_new_routine_deload_enabled.png`):**
     - Instead of `Goal` and `Description` text fields, Routine Edit has a 4-row grouped card:
       1. **`Progression`** (lime chart icon) → shows current policy (`Linear progression >`) and opens the **`Progression`** bottom sheet (`plan_routines_new_routine_progression_sheet.png`) with all 9 policies (`No automatic progression`, `Linear progression`, `Greyskull LP`, `Double progression`, `Steady double progression`, `Triple progression`, `Undulating days`, `Shorter rests`, `Skill ladder`), each with its full multi-line description and checkmark.
       2. **`Folder`** (blue folder icon) → shows current folder (`None >` or folder name) and opens the **`Folder`** bottom sheet (`plan_routines_new_routine_folder_sheet.png`) with description *"Group routines by block or by goal. Put old ones in Archive, it stays folded."*, `Folder name` input, `Archive` quick chip (plus existing folder chips), and full-width `Save` button.
       3. **`Routine type`** (lime stopwatch icon) → shows current mode (`Regular >`) and opens the **`Routine type`** bottom sheet (`plan_routines_new_routine_type_sheet.png`) with 6 options (`Regular`, `Circuit`, `AMRAP`, `EMOM`, `Intervals`, `Run/walk program`).
       4. **`Deload routine`** (orange slashed-chart icon) → subtitle *"Its workouts do not count toward progression. They still show in history and statistics."* + Switch toggle (`excludeFromProgression`).
     - Dynamic explanation caption under the card:
       - When `Deload routine` is OFF: displays the selected progression rule's description + *"Applies to every exercise in this routine that does not set its own rule."*
       - When `Deload routine` is ON (`plan_routines_new_routine_deload_enabled.png`): displays *"A deload routine opens at the numbers set here, so the progression above does not apply to it. The next regular target continues from the last included workout."*
  4. **`Add exercise` Picker Modal Sheet Layout (`Plan/plan_routines_new_routine_add_exercise_sheet.png`):**
     - Tapping `+ Add exercise` in Routine Edit opens a modal bottom sheet (not a full-screen `Scaffold` titled `'Select Exercise'`) with:
       - Header: `Add exercise` on the left, tonal `By muscle` button on the right.
       - Search field (`Search 5632 exercises...`) + grid/list toggle button.
       - 3 horizontal filter chip rows:
         1. `★ Chosen (N)`, `All`, `Back`, `Cardio`, `Chest`, `Full Body`...
         2. `Any type`, `Strength`, `Calisthenics`, `Olympic`, `Plyometrics`...
         3. `Any equipment`, `Body Weight`, `Dumbbell`, `Cable`...
       - `Create your own exercise` card (`name + body part, and a photo or video if you like`, `+`).
       - Exercise rows with thumbnail, name, `Target · Equipment`, and `+` button.
  5. **Exercise Row Layout, Supersets (`🔗` / `A1, A2`), Move Rail & `ExConfig` Sheet (`RoutineEdit.jsx:557-624`):**
     - Empty state (`plan_routines_new_routine.png`): centered dumbbell icon + `"No exercises yet. Add your first one!"` + superset tip `"🔗 Tap the link button on an exercise to superset it with the one above. You’ll do them back-to-back."`
     - Non-empty rows: show thumbnail, exercise name, compact summary line (`3 × 10 · 60 kg · 1:30`), optional `A1`/`A2` superset badge & editable superset/circuit header bar, and a right-hand action rail with `🔗` (link/unlink superset with exercise above), `^` (move up), `v` (move down), plus swipe-left to remove with Undo toast. Tapping an exercise row opens the `ExConfig` bottom sheet.
  6. **Missing `What this session hits` Muscle Coverage Card (`RoutineEdit.jsx:627-637`):**
     - When `entries.isNotEmpty`, Routine Edit displays a card below the exercises list titled `"What this session hits"` containing `BodyMapWidget` and chips for the top 6 worked muscles.
  7. **Missing Bottom Action Cards (`Copy routine`, `Share with a friend`, `Print / Save as PDF`, and `Delete routine`) (`RoutineEdit.jsx:642-661`, `Plan/plan_routines_new_routine.png`, `Plan/plan_routines_new_routine_copy.png`):**
     - Grouped card with `Copy routine` (creates `"<Name> (Copy)"` and navigates directly to the new copy!), `Share with a friend` (disabled when 0 exercises), and `Print / Save as PDF` (disabled when 0 exercises).
     - Separate danger card below with red trash icon, red title `Delete routine`, and subtitle `"“<Routine Name>” and its exercises will be removed."` (opens confirmation dialog `"Delete routine?"`).

#### 1.7 Active Workout Screen & Exercise Menu (`active_workout_screen.dart`, `workout_session_sheets.dart`, `exercise_menu_sheet.dart`) — **Partially Implemented**
- **What is done:** Header with minimize chevron, title, `Paused` prefix + elapsed timer + `done/total sets`, `⋯` workout menu sheet (with expandable `More`), `Finish` button, progress bar + total volume, `_PausedWorkoutBanner`, `_RestTimerBanner`, exercise number pills + compact `BodyMapWidget`, inline expandable/minimizable/pausable `ExerciseAnimationView`, per-exercise `⋯` menu sheet (`exercise_menu_sheet.dart` with expandable `More`), `"Not counted for progression"` row with `Undo`, set rows with `- / +` steppers and swipe-to-copy / swipe-to-delete, `< Prev` / `Next >` row, `Add exercise` / `Add session note` card, and `FinishWorkoutSheet` / `DiscardWorkoutDialog` / `WorkoutCompleteSummarySheet`.
- **Exact bugs / missing behaviors (comparing against `GymSessionStart/*.png` & `GymExerciseEdit/*.png`):**
  1. **Missing `Plan: X × Y` Prescription Line & `💡 <Progression Policy> · <Explanation>` Banner on Exercise Card (`GymSessionStart/01_workout_active_initial.png`, `04_workout_paused_state.png`, `GymExerciseEdit/Screenshot_20261117-102442.png`):**
     - Directly below the `[BodyPart]` `[Equipment]` chips (and optional `[Best: X kg]` chip when history exists), the exercise header must display:
       - `Plan: <sets> × <reps>` (and `Last time (<relative date>): <sets summary>` when prior history exists).
       - Progression insight banner with lightbulb icon:
         - When no prior history exists: `💡 Linear progression · Nothing logged yet, so this session sets the baseline.`
         - When prior history exists: e.g. `💡 Linear progression · Hit every target rep last time, so +2.5 kg.` (derived by `lib/progression-copy.js`).
  2. **Missing Plate Loading Sub-Text & `% of best e1RM` Record Hint Under Set Rows (`GymSessionStart/04_workout_paused_state.png`):**
     - For barbell exercises with `weight > barWeight`, displays plate breakdown (`25 + 2.5 per side (20 kg bar)`) and record hint (`97% of your best e1RM`) under the active set row.
  3. **Footer Text Says `Finish workout • X/Y sets` Instead of `Finish workout early · X/Y exercises` (`GymSessionStart/01_workout_active_initial.png` vs [active_workout_screen.dart:430](file:///c:/Users/kiann/Documents/CodingProjects/HouseKeepr/packages/open_gym/lib/src/ui/active_workout_screen.dart#L430)):**
     - When not all exercises are completed, the bottom text button reads `Finish workout early · <completedExercises>/<totalExercises> exercises`.
  4. **`showFinishWorkoutSheet` Shows `"Finish and save"` Even When 0 Sets Are Completed (`GymSessionStart/13_workout_nothing_logged_finish_sheet.png` vs [workout_session_sheets.dart:901-979](file:///c:/Users/kiann/Documents/CodingProjects/HouseKeepr/packages/open_gym/lib/src/ui/widgets/workout_session_sheets.dart#L901-L979)):**
     - In `13_workout_nothing_logged_finish_sheet.png` and `sheets.jsx:4696`, when `completedSets == 0` (`"Nothing logged yet"`), `"Finish and save"` is **NOT** shown—only the red **`Discard workout`** button and **`Keep going`** button are rendered!
  5. **Exercise Menu `More` Expansion Layout (`GymExerciseEdit/Screenshot_20261117-102444.png`, `102449.png`, `102452.png` vs [exercise_menu_sheet.dart](file:///c:/Users/kiann/Documents/CodingProjects/HouseKeepr/packages/open_gym/lib/src/ui/widgets/exercise_menu_sheet.dart)):**
     - Look at `Screenshot_20261117-102444.png` (collapsed) vs `102449.png` / `102452.png` (expanded):
       - When `More` is tapped, the `More` row itself disappears and is replaced by 3 titled section groups above `Remove exercise`:
         - Section `Exercise`: `Exercise settings (Linear progression)`, `Plate loading (Bar 20 kg)`, `How to do it`, `Watch on YouTube (Opens a search for good form)`.
         - Section `Order and supersets`: `Make superset with next`, `Move up` (dimmed when at index 0), `Move down` (dimmed when at last index).
         - Section `This session`: `Don't count for progression (This exercise, this session only)`.
       - Followed by the separate danger card `Remove exercise`.
       - Also note the `Rest timer` subtitle in `Screenshot_20261117-102444.png`: shows `Default (30s)` (or `Default (1:30)`) when using the profile default vs custom seconds.
  6. **`WorkoutCompleteSummarySheet` Missing `Last time and next time` Progression Cards, `Share workout`, and `Save as routine` (`GymSessionStart/15_workout_complete_summary_sheet.png` vs [workout_session_sheets.dart:1010-1165](file:///c:/Users/kiann/Documents/CodingProjects/HouseKeepr/packages/open_gym/lib/src/ui/widgets/workout_session_sheets.dart#L1010-L1165)):**
     - Screenshot `15_workout_complete_summary_sheet.png` includes:
       - Per-lift PR callout rows (`New PR: Barbell Bench Press 75 kg × 8`, `Best estimated 1RM: 95 kg`).
       - `LAST TIME AND NEXT TIME` comparison cards per exercise showing `Today`, `Last time`, and `Next time · step up` (`77.5 kg · 4 × 8`).
       - Editable `Session note` input field directly on the summary sheet.
       - `Share workout` and `Save as routine` buttons above `Done`.
  7. **`keepScreenAwake` Preference Not Wired to Wakelock:**
     - `OpenGymPreferences.keepScreenAwake` is toggled in `showWorkoutSettingsSheet`, but `WakelockPlus` is never called when starting/resuming/finishing a workout.
  8. **`Focus` Layout Mode (`FocusView.jsx`):**
     - `showLayoutPickerSheet` allows selecting `'focus'` (`Cards`, `List`, `Compact`, `Focus`), but `ActiveWorkoutScreen` treats `'focus'` identically to `'cards'` instead of rendering the one-set-at-a-time Focus view.

#### 1.8 Stats Tab (`stats_screen.dart` vs `views/Stats.jsx` & `stats_*.png`) — **Partially Implemented**
- **What is done:** 4-tab `SegmentedButton` (`Overview`, `Body`, `Lifts`, `Effort`), basic KPI card, `ActivityHeatmapWidget`, recent workouts list, Health Connect card, bodyweight line chart, `More` links (`Body measurements`, `Progress photos`, `Tools & Calculators`), lift dropdown + chart + `BodyMapWidget`, hard sets ratio bar, and time per exercise bars.
- **Exact bugs / missing behaviors:**
  1. **`Overview` Tab (`stats_overview.png`):**
     - Header top-right in `stats_overview.png` has a Report/Export icon button (`ReportSheet`) and History clock icon button.
     - KPI grid third metric in `stats_overview.png` is `Weight 30d` (30-day bodyweight delta, e.g. `-1 kg`) rather than `Streak`, and `Lifted in total` formats large volumes in tonnes (`78.6 t`), includes total duration (`7 workouts · 115 sets · 6 h`), and displays a fun weight comparison subtitle (*"About the weight of a space shuttle orbiter"* from `lib/lifetime.js`).
     - Missing the dedicated **`<N> week streak` card** with freeze count and milestone chips (`2w`, `4w`, `8w`, `12w`, `26w`, `52w`).
     - Missing the **`Cardio` weekly goal card** (`0 / 150 min`).
     - **Bug in Heatmap Toggle ([stats_screen.dart:211-220](file:///c:/Users/kiann/Documents/CodingProjects/HouseKeepr/packages/open_gym/lib/src/ui/stats_screen.dart#L211-L220)):** Toggling `_heatmapVolume` between `Time` and `Volume` does not pass `_heatmapVolume` to `ActivityHeatmapWidget`, which always counts workout frequency instead of shading cells by workout duration (`Time`) vs total volume (`Volume`).
  2. **`Body` Tab (`stats_body.png`):**
     - `Body weight` card is missing the `Goal <X>` button, `+ Log` button, range selector (`1M | 3M | 1Y | All`), and `Weekly change` rate row.
     - `MORE` list is missing `Structural balance` (*"See which lift is holding back the rest."*), `Journal` (*"Every note you wrote, in one place."*), and `Your year · So far` (`WrappedEntry.jsx`).
  3. **`Lifts` Tab (`stats_lifts.png`):**
     - `Exercise progress` card is missing the metric selector (`Top set` | `Est. 1RM` | `Volume` | `Best reps`), time range selector (`1M | 3M | 1Y | All`), and recent dates table with `RIR` badges.
     - `Muscles` card is missing the `Sets | Fatigue | Strength` mode tabs, `Completed | Planned` toggle, period dropdown (`Week` / `14d` / `30d`), horizontal target-range progress bars per muscle (`Target range` band + `Planned` tick mark + `Ranges` editor button), and `"Not trained in this period: N"` footer.
     - Missing the **`Strength level` card** (`StrengthLevel.jsx`: overall classification `Beginner`/`Novice`/`Intermediate`/`Advanced`/`Elite` + per-lift standards bars for Squat, Bench press, Deadlift, Overhead press).
  4. **`Effort` Tab (`stats_effort.png`):**
     - Missing the time range selector (`30d | 90d | 1Y | All`), average RIR headline (`1.8 RIR average effort`, `99% at RIR 3 or harder · X of Y finished sets rated`), `Week by week` inverted RIR line chart, and `Where the sets land` 5-bucket stacked distribution bar + legend (`RIR 0`, `RIR 1`, `RIR 2`, `RIR 3`, `RIR 4+`).

#### 1.9 Exercise Library, Explore Muscles & Skill Ladders (`exercise_library_screen.dart`, `explore_muscles_screen.dart`, `skill_ladders_sheet.dart`) — **Partially Implemented**
- **What is done:** 5,632 exercises loaded from `exercises.json`, search bar, grid/list toggle, `Filters` bottom sheet, body-part chips, custom exercise creation dialog, `.webp` thumbnails & `.mp4` detail sheet, interactive SVG `BodyMapWidget` muscle explorer, and `SkillLaddersSheet`.
- **Exact bugs / missing behaviors:**
  1. **Exercise Library Row Badges & Add-to-Plan Behavior (`exercises_list_1.png`):**
     - In `exercises_list_1.png`, exercises with logged history display a green pill badge with the user's best weight (e.g., `72.5`, `50`) to the left of the `+` button.
     - Tapping `+` on the Exercises tab in `Library.jsx` opens `addToRoutineSheet(ex)` (or adds to active workout if one is running), whereas Flutter's `_quickAddToWorkout` ([exercise_library_screen.dart:253-263](file:///c:/Users/kiann/Documents/CodingProjects/HouseKeepr/packages/open_gym/lib/src/ui/exercise_library_screen.dart#L253-L263)) always starts a brand-new empty workout immediately.
     - Missing exercise Favourites (`★`) star toggle and `★ Favourites` filter chip.
  2. **Explore Muscles Screen (`explore_muscles.png`, `explore_muscles_selected.png`):**
     - In `explore_muscles.png`, all 21 muscles are selectable (`Traps`, `Front delts`, `Side delts`, `Rear delts`, `Chest`, `Lats`, `Upper back`, `Serratus`, `Biceps`, `Triceps`, `Forearms`, `Abs`, `Obliques`, `Lower back`, `Glutes`, `Quads`, `Hamstrings`, `Adductors`, `Hip flexors`, `Calves`, `Shins`); when a muscle is selected (`explore_muscles_selected.png`), it shows `Primary` vs `Secondary` filter and equipment filter chips.
  3. **Skill Ladders Sheet (`skill_ladders_1.png`–`7.png` vs `skill_ladders_sheet.dart`):**
     - `skill_ladders_1.png`–`7.png` and `lib/ladders.js` define **7 built-in ladders**: `Push-up ladder`, `Pull-up ladder`, `Dip ladder`, `Squat ladder`, `Hinge ladder`, `Core ladder`, and `Handstand ladder`, plus a `+ Make your own ladder` button at the bottom (`skill_ladders_7.png`). Flutter's `skill_ladders_sheet.dart` only has 4 hardcoded ladders (missing `Dip`, `Hinge`, `Handstand`, and custom ladders).
     - Flutter's `skill_ladders_sheet.dart` hardcodes `'Not started'` and `'Start here'` on rung 0 instead of computing ladder progress from `controller.history` (`bestRung` / unlocked rungs).

#### 1.10 Programmes, Measurements, Progress Photos, Tools & History — **Partially Implemented**
- **Programmes (`programmes_screen.dart` vs `Programmes.jsx`):**
  - Flutter's `Programme` model is currently a 1-week `weekdayToTemplateId` map (which actually belongs on `OpenGymPreferences` / Fixed Week schedule!).
  - In `Programmes.jsx` and `lib/programmes.js`, a Programme is a **multi-week block (`1..52` weeks)** where each week has `deload` (`bool`), `rpe` (`double?`), and per-lift `%1RM` overrides (`Map<String, double>`), plus 3 starter programmes (`Strength block, 4 weeks`, `Upper / lower by effort, 6 weeks`, `Linear 5×5 style, 12 weeks`) and running state (`RunningCard` with progress bar, `Pause`/`Resume`, `Edit`, `End programme`).
- **Measurements (`measurements_screen.dart`):**
  - `BodyMeasurement` model already has `hipsCm`, `thighsCm`, `calvesCm`, `bpSys`, `bpDia`, `pulse`, `note`, but `MeasurementsScreen._addMeasurement` only renders inputs for Body Fat %, Waist, Chest, and Arms.
- **Workout History (`workout_history_screen.dart`):**
  - Hardcodes `'kg'` in 6 places (`L61, L81, L84, L121, L153, L174`) instead of `controller.preferences.weightUnit`.
  - Missing `Log past workout` (`logPastWorkoutSheet`), `Edit workout`, `Repeat today`, and `Save as routine` actions on `WorkoutLog` details.
- **Tools (`tools_screen.dart`):**
  - Implements Plate Loader, Warm-Up Ramp, and 1RM Estimator; missing RPE Load table, DOTS / Wilks / IPF GL powerlifting score calculator, BMI / FFMI / U.S. Navy Body Fat % calculator, and Running Pace converter (`views/Tools.jsx`).

---

## 2. Logic & Edge-Case Parity

### 2.1 Persisted State & Data Model Additions

1. **`WorkoutTemplate` (`packages/open_gym/lib/src/models/workout_template.dart`):**
   - Must add:
     - `String iconKey` (default `'overhead_press'`, mapping to the 20 routine glyphs in `Pick an icon`).
     - `String progressionPolicy` (default `'linear'`; one of `'off'`, `'linear'`, `'greyskull'`, `'double'`, `'steady'`, `'triple'`, `'undulating'`, `'density'`, `'ladder'`).
     - `String routineType` (default `'regular'`; one of `'regular'`, `'circuit'`, `'amrap'`, `'emom'`, `'intervals'`, `'runwalk'`).
     - `bool isDeload` (`excludeFromProgression`, default `false`).
     - `Map<String, dynamic>? circuitConfig` (stores `rounds`, `gapSeconds`, `capSeconds`, `everySeconds`, `intervalCount`, `workSeconds`, `restSeconds`, `runWalkLevel`, `runWalkCompletedSessions`).
2. **`WorkoutTemplateEntry` (`packages/open_gym/lib/src/models/workout_template.dart`):**
   - Must add:
     - `ExerciseMode mode` (`reps`, `time`, `distance`, `cardio`).
     - `int? targetRepsMin` (bottom of rep range for `double`, `steady`, `triple`, `ladder`).
     - `int? targetSetsMax` (set ceiling for `triple` progression).
     - `int? targetDurationSeconds` (for `time` / `cardio` mode).
     - `double? targetDistanceMeters` (for `distance` mode).
     - `String? progressionPolicy` (per-exercise override; `null` inherits from `WorkoutTemplate.progressionPolicy`).
     - `double deloadFactor` (default `0.90`).
     - `String? supersetId` (`sg` group identifier so adjacent entries sharing `supersetId` form superset `A1/A2`, `B1/B2`).
     - `String? supersetName` (`sgName`) and `int? supersetRestSeconds` (`sgRest`).
     - `String? note` (standing plan note for this slot).
     - `String warmupMode` (`'auto'`, `'own'`, `'none'`).
     - `SetType intensifierType` (`straight`, `dropset`, `restpause`, `cluster`).
3. **`OpenGymPreferences` (`packages/open_gym/lib/src/models/server_connection.dart`):**
   - Must add:
     - `List<String> rotationSequence`: ordered list of stop IDs in `The loop`, where each element is either a `WorkoutTemplate.id` or `'rest'` (`Rest day`). Defaults to initial starter template IDs `[t1.id, t2.id, t3.id]`.
     - `List<int> rotationCompletedIndices`: indices in `rotationSequence` completed during the current pass/round.
     - `Map<int, List<String>> weeklySchedule`: Fixed Week mapping of ISO weekday (`1..7`, Monday–Sunday) to one or more `WorkoutTemplate.id`s (defaulting Monday=`Push Day`, Wednesday=`Pull Day`, Friday=`Leg Day`).
     - `Map<int, bool> weeklyTrainSeparately`: (`weekApart`) whether multiple routines on the same weekday are trained separately or merged into one session.
     - `Map<String, String> dayOverrides`: (`dayPlan`) mapping `YYYY-MM-DD` to a `WorkoutTemplate.id` or `'rest'`.
     - `Map<String, bool> folderOpenState`: per-folder expanded/collapsed map (where `'archive'` defaults to `false`).
     - `Set<String> favoriteExerciseIds`: (`favEx`) starred exercise IDs.

### 2.2 Schedule & Rotation Loop State Machine (`lib/rotation.js`, `Plan.jsx`)

- **Stop Sequence (`rotationSequence`):**
  - May contain any routine ID one or more times, plus `'rest'` (`Rest day`) stops at any position.
  - **Current Stop (`Up next`):** The first index `i` in `rotationSequence` that is not in `rotationCompletedIndices` and is not `'rest'`.
  - **Completing a Workout in Rotation Mode:**
    - When a workout matching stop `i` finishes, `i` (and any immediately following `'rest'` stop) is marked completed in `rotationCompletedIndices`, and `rotationIndex` advances to the next uncompleted routine stop.
    - Once all routine stops in `rotationSequence` have been completed, the pass rolls over (`rotationCompletedIndices` resets to empty, starting a new round).
  - **`Start the loop over` (`startNewPass`):**
    - Clears `rotationCompletedIndices` and resets `rotationIndex = 0`.
  - **`takeOutOfLoop(int index)` with Snapshot Undo:**
    - Captures a snapshot `{ rotationSequence, rotationCompletedIndices, rotationIndex }` before removing `rotationSequence.removeAt(index)`.
    - Displays a floating SnackBar/Toast `"“<Stop Name>” is out of the loop."` with an `Undo` action that restores the exact snapshot.
  - **Switching `Rotation` → `Fixed Week` (`Plan.jsx:242-252`):**
    - If `rotationSequence.isNotEmpty`, prompts the `Back to a fixed week?` confirmation dialog. On confirm, sets `trainingMode = 'fixed_week'` while leaving `rotationSequence` and `weeklySchedule` intact.

### 2.3 Routine CRUD, Duplicate, Delete & Undo Snapshot Rules (`lib/routines.js`, `Plan.jsx`, `RoutineEdit.jsx`)

- **Immediate Creation on `+ New routine`:**
  - Creates `WorkoutTemplate.create(name: 'New routine', iconKey: 'overhead_press', progressionPolicy: 'linear', entries: [])`, persists it immediately via `controller.saveTemplate(template)`, and navigates to `RoutineEdit`.
- **Two Distinct Duplicate Flows:**
  1. **Swipe-Right on Plan → Routines (`Plan.jsx:458-470`):**
     - Clones `template` with a new UUID and `name: '${template.name} (Copy)'`.
     - Inserts the copy at `indexOf(template) + 1` in `controller.templates` (staying on the `Plan → Routines` list).
     - Shows toast `"Copied as “${copy.name}”."` with `Undo` (which deletes `copy.id`).
  2. **`Copy routine` Row Inside RoutineEdit (`RoutineEdit.jsx:643-647`):**
     - Clones `template` with a new UUID and `name: '${template.name} (Copy)'`.
     - Appends to `controller.templates` and navigates `RoutineEdit` directly to the new copy (`Plan/plan_routines_new_routine_copy.png`).
- **Delete with Full Undo Snapshot (`deleteRoutineWithUndo` in `Plan.jsx:53-70` & `lib/routines.js`):**
  - Captures `RoutineSnapshot`:
    - The deleted `WorkoutTemplate` and its index in `templates`.
    - Its positions in `preferences.weeklySchedule`.
    - Its positions in `preferences.rotationSequence` and `rotationCompletedIndices`.
    - Any date keys in `preferences.dayOverrides`.
  - Removes the routine from `templates`, `weeklySchedule`, `rotationSequence`, and `dayOverrides`.
  - When triggered via swipe-left or Edit-mode minus on `Plan → Routines`, shows toast `"“${template.name}” gone."` with `Undo` to restore the entire `RoutineSnapshot`. When triggered via the red `Delete routine` row at the bottom of `RoutineEdit`, shows a confirmation dialog `"Delete routine?"` first, then deletes and pops back to `Plan`.

### 2.4 Automatic Progression Engine (`lib/progression.js` & `lib/progression-copy.js`)

For each exercise entry when starting a workout (and for rendering the `💡` banner on `ActiveWorkoutScreen` and `LAST TIME AND NEXT TIME` on `WorkoutCompleteSummarySheet`):
- Filter `controller.history` for completed workouts where `workout.countForProgression && entry.countForProgression`.
- Exclude warm-up sets (`set.isWarmup`). Grade the first `plannedSets` work sets.
- A session is **clean (`ok == true`)** iff `completedWorkSets.length >= plannedSets` and every graded work set achieved `reps >= targetReps` (or `durationSeconds >= targetDurationSeconds` in `time` mode).
- Apply the active policy (`entry.progressionPolicy ?? template.progressionPolicy`):
  1. **`off`**: Keep planned weight and reps; banner: `"No automatic progression · Targets stay where you set them."`
  2. **`linear`**:
     - If no prior history: prescribe routine `defaultWeight` × `targetReps`; banner: `"Linear progression · Nothing logged yet, so this session sets the baseline."`
     - If last session `ok`: `nextWeight = lastWeight + increment` (default `+2.5 kg` / `+5 lb`); banner: `"Linear progression · Hit every target rep last time, so +2.5 kg."`
     - If 3 consecutive stalls (`stalls >= 3`): deload to Epley `0.90` equivalent weight snapped to `increment`; banner: `"Linear progression · Missed 3 times in a row, so −10% deload to rebuild."`
     - Else (1–2 misses): hold `lastWeight`; banner: `"Linear progression · Missed target reps last time, so same weight again."`
  3. **`greyskull`**:
     - Same as `linear`, except if the final work set achieved `>= targetReps * 2`, step weight by `2 * increment`; and deload by `10%` after just **1** missed session (`DELOAD_AFTER = 1`).
  4. **`double`**:
     - Rep range `[repsMin, targetReps]`. If `lastLowestReps >= targetReps`, step `weight + increment` and reset target reps to `repsMin`. Otherwise, target reps = `min(targetReps, max(repsMin, lastLowestReps + 1))` at `lastWeight`. Beating best `low` reps at current weight resets stall counter.
  5. **`steady`**:
     - Like `double`, except target reps only increment by `+1` when **every** set in the last session met the previous session's aimed rep count.
  6. **`triple`**:
     - Climbs reps from `repsMin` to `targetReps` across `targetSets`. When all current sets hit `targetReps` and `currentSets < targetSetsMax`, adds `+1 set` at `repsMin`. When all `targetSetsMax` sets hit `targetReps`, steps `weight + increment` and resets to `targetSets × repsMin`.
  7. **`undulating` (DUP)**:
     - Rotates day index `sessionCount % 3`: `0` = Medium (`1.0 × targetReps`), `1` = Heavy (`round(0.6 × targetReps)`), `2` = Light (`round(1.5 × targetReps)`), prescribing weight from rolling 3-session Epley 1RM at `RIR 2`: $w = \frac{\text{1RM}}{1 + (\text{dayReps} + 2)/30}$ snapped to `increment`.
  8. **`density`**:
     - Keeps weight constant and reduces `restSeconds` by `15s` after each clean session down to `45s` floor; a clean session at `45s` steps `weight + increment` and resets `restSeconds` to template default.
  9. **`ladder`**:
     - Climbs reps in `[repsMin, targetReps]`; when all sets hit `targetReps`, recommends advancing to the next rung in the exercise's calisthenics skill ladder.

### 2.5 Superset Grouping & Unit Reordering (`lib/history.js`, `RoutineEdit.jsx`)

- Adjacent entries sharing a non-null `supersetId` (`sg`) form a superset unit.
- Each multi-entry unit `k` (`0, 1, 2...`) assigns position badges `A1, A2...`, `B1, B2...` (`String.fromCharCode(65 + k) + '${memberIndex + 1}'`).
- **`cleanupSg(List<WorkoutTemplateEntry> entries)`:** Any `supersetId` that appears on only 1 contiguous entry (and has no `circuitConfig`) is cleared to `null` so orphaned single exercises never retain a stale superset badge.
- **Toggling Superset Link (`toggleLink(int index)` on `index > 0`):**
  - If `entries[index].supersetId != null && entries[index].supersetId == entries[index - 1].supersetId`, clears `entries[index].supersetId = null` and runs `cleanupSg`.
  - Otherwise, sets `gid = entries[index - 1].supersetId ?? 'sg_${uuid}'` on both `entries[index - 1]` and `entries[index]`.

### 2.6 Wall-Clock Anchored Timers & Wakelock (`store/useUI.js`, `open_gym_controller.dart`)

- **Wall-Clock Timers:**
  - `OpenGymController` currently tracks `_elapsedSeconds++` and `_restRemainingSeconds--` inside `Timer.periodic(const Duration(seconds: 1))`. If the OS suspends the app or locks the screen, `Timer.periodic` pauses and drifts.
  - Must store `DateTime? _workoutStartedAt`, `Duration _accumulatedPausedDuration`, `DateTime? _pausedAt`, and `DateTime? _restEndsAt`.
  - A `250ms` ticker computes `elapsedSeconds` and `restRemainingSeconds = ((_restEndsAt!.difference(DateTime.now()).inMilliseconds) / 1000).ceil()`, firing `playCountdownTick()` at `3, 2, 1` seconds (deduplicated per second) and `playRestEndChime()` at `<= 0`.
- **Wakelock (`wakelock_plus`):**
  - When an active workout is running and `!isPaused` and `preferences.keepScreenAwake == true`, enable `WakelockPlus.enable()`; disable when paused, finished, discarded, or `keepScreenAwake == false`.

---

## 3. Visual & Layout Deltas (Screenshots vs. Current Flutter UI)

### 3.1 Plan Tab & Routine Edit Visual Deltas (`assets/HealthKeeprDesign/OpenGym/Plan/*.png`)

1. **Top AppBar Removal on Tabs 1–3 (`plan_routines.png`, `plan_schedule_rotation.png`, `stats_overview.png`, `exercises_list_1.png`):**
   - Remove the outer `Scaffold.appBar` (`'OpenGym'`) when `_tabIndex != 0` in `OpenGymDashboardScreen` so `Plan`, `Stats`, and `Exercises` match the top spacing and clean header typography of the screenshots.
2. **Plan Header & Share Button (`plan_routines.png`, `plan_routines_share_sheet.png`):**
   - Left: `Plan` (`headlineMedium`, bold) + subtitle (`Your routines in a loop` in Rotation mode; `Your weekly routine` in Fixed Week mode).
   - Right: Circular tonal icon button (`Icons.ios_share_rounded`) opening the 7-item `Plan` modal bottom sheet (`plan_routines_share_sheet.png`).
3. **Segmented Toggle Styling (`plan_routines.png`, `plan_schedule_rotation.png`):**
   - Full-width 2-pill container (`Schedule` | `Routines`) with `showSelectedIcon: false` (no checkmark prefix inside the selected segment).
4. **Routines View Action Row & Routine Cards (`plan_routines.png`, `plan_routines_edit.png`, `plan_routines_swipe_delete.png`, `plan_routines_swipe_duplicate.png`):**
   - Action row: `Edit` text button on left (turns into `Done` when editing), tonal `+ New routine` pill button on right. Remove the bottom-right `FloatingActionButton`.
   - Routine Card (Normal mode):
     - Leading: `40×40` rounded square (`borderRadius: 10`, `colorScheme.primary` background, `colorScheme.onPrimary` icon) rendering the routine's custom glyph.
     - Title: Routine name (preceded by gold `Icons.star_rounded` if `isFavorite`).
     - Subtitle: `${entries.length} exercises` + (if assigned to weekdays: ` · ${weekdayShortNames.join(', ')}`).
     - Trailing: Compact `BodyMapWidget` (**only when `entries.isNotEmpty`**) + `Icons.chevron_right`.
     - Wrapped in bilateral `Dismissible` / custom swipe row:
       - Swipe right (`startToEnd`): lime background with `Icons.copy_rounded` + `"Duplicate"` label → duplicates routine in-place below current card + shows bottom toast `"Copied as “<Name> (Copy)”."` with `↺ Undo` button (`plan_routines_swipe_duplicate.png`).
       - Swipe left (`endToStart`): red background with `Icons.delete_outline` + `"Delete"` label → deletes routine + shows bottom toast `"“<Name>” gone."` with `↺ Undo` button (`plan_routines_swipe_delete.png`).
   - Routine Card (`Edit` mode, `plan_routines_edit.png`):
     - Leading: Red circle minus button (`Icons.remove_circle`, `Colors.redAccent`) + `40×40` lime glyph square.
     - Trailing: `Icons.unfold_more_rounded` drag handle (hiding `BodyMapWidget` and chevron).
5. **Schedule View — Rotation Mode (`plan_schedule_rotation.png`, `plan_schedule_rotation_edit.png`, `plan_schedule_rotation_edit_add_sheet.png`, `plan_schedule_rotation_swipe_remove.png`, `plan_schedule_rotation_to_fixed_week_dialog.png`):**
   - `How you train` card with orange rounded-square `Icons.repeat_rounded` badge + full-width `Fixed Week` | `Rotation` segmented toggle + explanatory footer caption below the card.
   - `The loop` header row: `"The loop"` title on left, `Edit` / `Done` text button + tonal `+ Add` pill button on right.
   - Loop Stop Row:
     - In Edit mode: red circle minus button on far left.
     - Step number circle (`28×28`): lime background when `isNext`, checkmark icon when `isDone`, muted surface circle with `${idx + 1}` otherwise.
     - Glyph square (`40×40`): lime square with routine glyph for routines; muted dark square with crescent moon icon (`Icons.nightlight_outlined`) for `Rest day`.
     - Title & Subtitle:
       - Routine stop: routine name + (`Up next` if current stop, `Done` if completed in current round, or `${entries.length} exercises`).
       - Rest day stop: `Rest day` + `A day off before the next one`.
     - Trailing: Compact `BodyMapWidget` for routine stops (hidden on `Rest day` stops and in `Edit` mode); `Icons.unfold_more_rounded` drag handle in `Edit` mode.
     - Swipe left (`endToStart`, `plan_schedule_rotation_swipe_remove.png`): red background with `— Remove` → removes stop from `rotationSequence` with Undo toast.
   - Footer caption below loop: `"${doneCount} of ${totalRoutineStops} done this round. ${isEditing ? 'Drag to reorder. Tap the minus to take one out.' : 'Trained out of order? Just pick another routine on Home.'}"`
   - Left-aligned `↺ Start the loop over` text button below the caption.
6. **Routine Edit Screen (`plan_routines_new_routine*.png`):**
   - Top bar: circular `<` button, rounded filled `TextField` for routine name, circular Star toggle button (`☆`/`★`), circular Glyph picker button.
   - 4-row grouped card (`Progression`, `Folder`, `Routine type`, `Deload routine` switch) + dynamic caption below.
   - `Exercises` header with tonal `+ Add exercise` button on right.
   - Empty state with dumbbell icon + `"No exercises yet. Add your first one!"` + link hint `"🔗 Tap the link button on an exercise to superset it with the one above. You’ll do them back-to-back."`
   - Non-empty exercise rows with thumbnail, name, prescription summary (`3 × 10 · 60 kg · 1:30`), `🔗` / `^` / `v` action rail, and `"What this session hits"` `BodyMapWidget` card.
   - Bottom 3-row action card (`Copy routine`, `Share with a friend`, `Print / Save as PDF`) + separate red `Delete routine` card.

### 3.2 Active Workout & Exercise Menu Visual Deltas (`GymSessionStart/*.png`, `GymExerciseEdit/*.png`)

1. **Exercise Header Metadata & Progression Insight Banner (`01_workout_active_initial.png`, `04_workout_paused_state.png`, `Screenshot_20261117-102442.png`):**
   - Show `[BodyPart]`, `[Equipment]`, and conditional `[Best: X kg]` chips.
   - Show `Plan: <sets> × <reps>` and conditional `Last time (<date>): <summary>`.
   - Show `💡 <Policy Name> · <Reason>` row with primary/lime highlight on the policy name.
2. **Exercise Options Sheet `More` Expansion (`Screenshot_20261117-102444.png`, `102449.png`, `102452.png`):**
   - Collapsed state shows 5 grouped items (`Add note`, `Swap exercise`, `Add warm-up set`, `Rest timer` with `Default (Xs)` subtitle, `History`), a separate `More` card (`Exercise settings, Plate loading, How to do it, Watch on Yo...`), and a separate red `Remove exercise` card.
   - Expanding `More` replaces the `More` card with 3 titled section cards (`Exercise`, `Order and supersets`, `This session`) above `Remove exercise`, where `Plate loading` shows subtitle `Bar 20 kg` and opens the bar/plate configuration sheet.
3. **Nothing Logged Yet Finish Sheet (`13_workout_nothing_logged_finish_sheet.png`):**
   - Hide `"Finish and save"` when `workout.completedSetsCount == 0`; show only red `"Discard workout"` and tonal `"Keep going"`.
4. **Workout Complete Summary Sheet (`15_workout_complete_summary_sheet.png`):**
   - Add per-exercise PR callout list, `LAST TIME AND NEXT TIME` comparison cards, inline `Session note` text field, `Share workout`, and `Save as routine` buttons.

---

## 4. Flutter Architecture Mapping

All changes map cleanly onto our existing two-package architecture without introducing new state management frameworks or duplicating utilities:

1. **Storage & Persistence Layer (`packages/health_keepr` & `packages/open_gym/lib/src/state/open_gym_repository.dart`):**
   - Continue using `HealthDataStore` (`LocalHealthDataStore` backed by Hive JSON boxes under `moduleId = 'open_gym'`).
   - All new fields on `WorkoutTemplate`, `WorkoutTemplateEntry`, `OpenGymPreferences`, `Programme`, and `WorkoutEntry` serialize in `toJson()` / `fromJson()` with backward-compatible defaults so existing local data migrates seamlessly.
2. **State & Domain Services Layer (`packages/open_gym/lib/src/state/`):**
   - **`open_gym_controller.dart` (`OpenGymController extends ChangeNotifier`):**
     - Add rotation loop mutators: `addStopToRotation(String idOrRest)`, `removeStopFromRotation(int index)`, `restoreRotationSnapshot(RotationSnapshot snap)`, `reorderRotation(int oldIndex, int newIndex)`, `resetRotationPass()`.
     - Add weekday schedule mutators: `assignWeekdayRoutines(int weekday, List<String> templateIds, {bool trainSeparately = false})`, `setDayOverride(String dateIso, String? templateIdOrRest)`.
     - Add routine lifecycle methods: `createNewRoutineAndReturn()`, `duplicateTemplateInPlace(String templateId, {int? insertAt})`, `deleteTemplateWithSnapshot(String templateId)`, `restoreTemplateSnapshot(RoutineDeleteSnapshot snap)`, `reorderTemplates(int oldIndex, int newIndex)`, `toggleTemplateFavorite(String templateId)`, `setTemplateFolder(String templateId, String? folder)`.
     - Upgrade workout & rest timers to wall-clock timestamps (`_workoutStartedAt`, `_restEndsAt`) with `250ms` tick check + `WakelockPlus` integration.
   - **`progression_service.dart` [NEW] (`packages/open_gym/lib/src/state/progression_service.dart`):**
     - Pure service porting `lib/progression.js` & `lib/progression-copy.js` (all 9 progression policies, `PrescriptionResult` with `nextWeight`, `nextReps`, `nextSets`, `nextRestSeconds`, `policyLabel`, `explanationBanner`, and post-workout `LastAndNextComparison`).
   - **`analytics_service.dart` & `personal_record_service.dart`:**
     - Extend `OpenGymAnalyticsService` with bounded-knapsack plate solver (`plateStack`, `plateDelta` from `lib/plates.js`), 30-day weight rate/delta (`lib/bodyweight.js`), muscle fatigue half-life decay & retained strength (`lib/recovery.js`), and strength standards (`lib/strength-level.js`).
     - Extend `OneRmEstimator` in `personal_record_service.dart` with RIR-aware weighted ensemble (`effectiveReps = reps + rir`).
3. **Reusable UI Widgets & Sheets (`packages/open_gym/lib/src/ui/`):**
   - **`widgets/routine_glyph_icon.dart` [NEW]:** Maps the 20 routine icon keys across `Strength`, `Equipment`, `Cardio`, `Recovery` to custom vector/Material icons, plus the reusable `40×40` lime rounded-square glyph badge and `showRoutineGlyphPickerSheet`.
   - **`widgets/undo_toast.dart` [NEW]:** Floating dark pill toast matching `Plan/plan_routines_swipe_duplicate.png` and `plan_routines_new_routine_copy_starred.png` (`"Copied as “Push Day (Copy)”."` + lime `↺ Undo` button + `×` dismiss).
   - **`widgets/plan_sheets.dart` [NEW]:**
     - `showPlanOptionsSheet` (`Export plan file`, `Print / Save as PDF`, `Import a plan file`, `Scan a QR code`, `Load starter plan`, `Routine from a past workout`, `Programmes`)
     - `showStarterPlanSheet` (Gym & Home starter plans)
     - `showAddToRotationSheet` (`Rest day` + routines with `"Already in the loop: adds it again"`)
     - `showBackToFixedWeekDialog` (`Back to a fixed week?` centered modal)
     - `showDayAssignSheet` (multi-routine picker per weekday + `Together | Separately` + `Rest day`)
     - `showRoutineProgressionSheet` (9 policies with descriptions)
     - `showRoutineFolderSheet` (`Folder name` input + `Archive` chip + `Save`)
     - `showRoutineTypeSheet` (`Regular`, `Circuit`, `AMRAP`, `EMOM`, `Intervals`, `Run/walk program`)
     - `showExerciseConfigSheet` (`ExConfig` per-slot editor for mode, sets/reps/range, weight, rest, progression override, warm-up mode, intensifiers, and notes).
   - **Existing Screens Updated in Place:**
     - `open_gym_dashboard_screen.dart` (`OpenGymDashboardScreen`, `_HomeTab`, `_PlanTab`)
     - `routine_builder_screen.dart` (refactored to auto-saving `RoutineEdit` layout matching `Plan/plan_routines_new_routine*.png`)
     - `active_workout_screen.dart`, `widgets/workout_session_sheets.dart`, `widgets/exercise_menu_sheet.dart`
     - `stats_screen.dart`, `widgets/activity_heatmap_widget.dart`
     - `exercise_library_screen.dart`, `explore_muscles_screen.dart`, `skill_ladders_sheet.dart`
     - `programmes_screen.dart`, `measurements_screen.dart`, `tools_screen.dart`, `workout_history_screen.dart`.

---

## 5. Sequential Implementation Milestones

### Milestone 1: Data Models, Schema Extensions & Repository Migration
- **Files:** `workout_template.dart`, `server_connection.dart` (`OpenGymPreferences`), `programme.dart`, `workout_log.dart`, `open_gym_repository.dart`.
- **Tasks:**
  1. Add `iconKey`, `progressionPolicy`, `routineType`, `isDeload`, `circuitConfig` to `WorkoutTemplate`.
  2. Add `mode`, `targetRepsMin`, `targetSetsMax`, `targetDurationSeconds`, `targetDistanceMeters`, `progressionPolicy`, `deloadFactor`, `supersetId`, `supersetName`, `supersetRestSeconds`, `note`, `warmupMode`, `intensifierType` to `WorkoutTemplateEntry`.
  3. Add `rotationSequence`, `rotationCompletedIndices`, `weeklySchedule`, `weeklyTrainSeparately`, `dayOverrides`, `folderOpenState`, `favoriteExerciseIds` to `OpenGymPreferences`.
  4. Upgrade `Programme` model to support multi-week blocks (`weeks` list with `deload`, `rpe`, and per-lift `%1RM` targets, plus `isRunning`, `startedAt`, `pausedAt`).
- **Verification:** Unit tests in `packages/open_gym/test/open_gym_test.dart` verifying JSON round-trip serialization and backward-compatible deserialization from legacy records.

### Milestone 2: Core Business Logic — Progression, Rotation Queue, Undo Snapshots & Wall-Clock Timers
- **Files:** `progression_service.dart` [NEW], `open_gym_controller.dart`, `analytics_service.dart`, `personal_record_service.dart`.
- **Tasks:**
  1. Implement `ProgressionService` with all 9 policies (`off`, `linear`, `greyskull`, `double`, `steady`, `triple`, `undulating`, `density`, `ladder`), baseline/hit/stall/deload detection, and human-readable insight copy (`💡 Linear progression · ...`) + post-workout `LastAndNextComparison`.
  2. Implement `rotationSequence` queue logic in `OpenGymController` (supporting `'rest'` stops, duplicate routine stops, `rotationCompletedIndices` tracking, `takeOutOfLoop` with `RotationSnapshot` undo, and `resetRotationPass`).
  3. Implement `RoutineDeleteSnapshot` and `deleteTemplateWithSnapshot` / `restoreTemplateSnapshot`, `duplicateTemplateInPlace`, `reorderTemplates`, and superset unit helpers (`supersetUnits`, `toggleTemplateEntrySuperset`, `cleanupSg`).
  4. Refactor `OpenGymController` workout and rest timers to wall-clock `DateTime` anchoring (`250ms` poll) and wire `keepScreenAwake` to `wakelock_plus`.
- **Verification:** Unit tests covering all 9 progression rules, stall deloads, rotation loop with rest days & duplicate routines, routine delete/restore snapshots, and timer accuracy.

### Milestone 3: Plan Tab — Header, Plan Options Sheet & Schedule View (Rotation Loop + Fixed Week)
- **Files:** `open_gym_dashboard_screen.dart`, `widgets/plan_sheets.dart` [NEW], `widgets/routine_glyph_icon.dart` [NEW], `widgets/undo_toast.dart` [NEW].
- **Tasks:**
  1. Remove redundant top `'OpenGym'` `AppBar` on tabs 1–3 and remove the Plan `FloatingActionButton`.
  2. Add the top-right share/menu icon button on `Plan` opening `showPlanOptionsSheet` (`plan_routines_share_sheet.png`) and wire `Export plan file`, `Print / Save as PDF`, `Import a plan file`, `Scan a QR code`, `Load starter plan`, `Routine from a past workout`, and `Programmes`.
  3. Update `How you train` card with orange repeat badge, `Fixed Week` | `Rotation` segmented control (`showSelectedIcon: false`), explanatory footer caption, and `showBackToFixedWeekDialog` (`plan_schedule_rotation_to_fixed_week_dialog.png`).
  4. Build the full `The loop` section (`plan_schedule_rotation.png`, `plan_schedule_rotation_edit.png`, `plan_schedule_rotation_edit_add_sheet.png`, `plan_schedule_rotation_swipe_remove.png`): `Edit`/`Done` + `+ Add` header buttons, `Rest day` moon rows & routine glyph rows, edit-mode red minus + drag handles, swipe-left `Remove` with Undo toast, round progress caption, and bottom `↺ Start the loop over` button.
  5. Build the inline Fixed Week 7-day schedule (`plan_schedule.png`) with `showDayAssignSheet` and bottom `Weekly muscle volume` link card.
- **Verification:** Widget tests verifying Schedule Rotation view, adding a `Rest day` and duplicate routine to the loop, Edit mode reordering/removal, swipe removal with Undo, Fixed Week confirmation dialog, and weekday assignment.

### Milestone 4: Plan Tab — Routines View & Auto-Saving Routine Edit Screen
- **Files:** `open_gym_dashboard_screen.dart`, `routine_builder_screen.dart`, `widgets/plan_sheets.dart`, `widgets/routine_glyph_icon.dart`.
- **Tasks:**
  1. Update `Plan → Routines` view (`plan_routines.png`, `plan_routines_edit.png`, `plan_routines_swipe_delete.png`, `plan_routines_swipe_duplicate.png`): top action bar (`Edit`/`Done` + tonal `+ New routine`), `★ Favourites` section, collapsible `Folder` sections (`"Archive"` folded by default), lime glyph badges, `<N> exercises · <Days>` subtitles, conditional mini `BodyMapWidget` (hidden when `0 exercises`), Edit mode (red minus + drag handle), swipe-left `Delete` with Undo toast, and swipe-right `Duplicate` in-place with Undo toast.
  2. Refactor `RoutineBuilderScreen` into the live auto-saving `RoutineEdit` screen (`plan_routines_new_routine*.png`):
     - Immediate creation of `"New routine"` with `0 exercises` when tapping `+ New routine`.
     - Header with `<` back button, filled routine name input, Star button (`☆`/`★` with `"Starred. It leads your routines now."` toast), and Icon picker button (`showRoutineGlyphPickerSheet` with 20 icons across 4 categories).
     - 4-row grouped card (`Progression` → 9-policy sheet, `Folder` → Folder sheet with `Archive` chip, `Routine type` → 6-mode sheet, `Deload routine` switch) + dynamic explanation caption.
     - `Exercises` section with tonal `+ Add exercise` button opening the 3-chip-row `Add exercise` modal bottom sheet (`plan_routines_new_routine_add_exercise_sheet.png`), empty dumbbell state, exercise rows with `A1/A2` superset badges + `🔗`/`^`/`v` rail + `ExConfig` sheet, and `"What this session hits"` `BodyMapWidget` card.
     - Bottom 3-row action card (`Copy routine` navigating to `"<Name> (Copy)"`, `Share with a friend`, `Print / Save as PDF`) and red `Delete routine` card.
- **Verification:** Widget tests verifying instant `+ New routine` creation with 0 exercises, star toggle, icon picker, progression/folder/type sheets, deload caption toggle, `Copy routine` navigation, and swipe duplicate/delete with Undo on the Routines list.

### Milestone 5: Active Workout, Exercise Menu, Plate Math & Finish Flow Parity
- **Files:** `active_workout_screen.dart`, `widgets/exercise_menu_sheet.dart`, `widgets/workout_session_sheets.dart`.
- **Tasks:**
  1. Add `[Best: X kg]` chip, `Plan: X × Y` line, `Last time:` line, and `💡 <Progression Policy> · <Explanation>` banner to `_buildExerciseSection` in `ActiveWorkoutScreen` (`01_workout_active_initial.png`, `04_workout_paused_state.png`).
  2. Add per-set plate math breakdown (`25 + 2.5 per side (20 kg bar)`) and `% of your best e1RM` hint under work sets, and update the bottom button text to `Finish workout early · X/Y exercises`.
  3. Update `showExerciseMenuSheet` (`Screenshot_20261117-102444.png`, `102449.png`, `102452.png`) so `Rest timer` shows `Default (Xs)`, and expanding `More` replaces the `More` card with the 3 titled sections (`Exercise` including `Plate loading / Bar 20 kg`, `Order and supersets`, `This session`) above `Remove exercise`.
  4. Fix `showFinishWorkoutSheet` (`13_workout_nothing_logged_finish_sheet.png`) to omit `"Finish and save"` when `workout.completedSetsCount == 0`.
  5. Enhance `showWorkoutCompleteSummarySheet` (`15_workout_complete_summary_sheet.png`) with PR callout rows, `LAST TIME AND NEXT TIME` progression cards, inline `Session note` field, `Share workout`, and `Save as routine`.
  6. Implement one-set-at-a-time `Focus` layout mode and `CircuitPlayer` sheet for `circuit`/`amrap`/`emom`/`intervals`/`runwalk` routines.
- **Verification:** Widget tests covering active workout progression banner, exercise menu `More` sections, 0-set finish sheet (`Discard workout` / `Keep going` only), and post-workout summary comparison cards.

### Milestone 6: Home, Stats, Exercises Library, Skill Ladders, Programmes & Tools Parity
- **Files:** `open_gym_dashboard_screen.dart` (`_HomeTab`), `stats_screen.dart`, `widgets/activity_heatmap_widget.dart`, `exercise_library_screen.dart`, `explore_muscles_screen.dart`, `skill_ladders_sheet.dart`, `programmes_screen.dart`, `measurements_screen.dart`, `tools_screen.dart`, `workout_history_screen.dart`.
- **Tasks:**
  1. **Home Tab (`home.png`):** Add 7-day `< This week >` strip with `dayOverrideSheet`, `AT THE GYM / Check in` QR card, Body weight delta/weekly rate/goal button (`GoalSheet`), and `2 week streak` card.
  2. **Stats Tab (`stats_*.png`):**
     - `Overview`: Wire `_heatmapVolume` (`Time` vs `Volume`) into `ActivityHeatmapWidget`, add `Weight 30d` KPI, tonnes formatting + space shuttle comparison, `<N> week streak` card with milestone chips, and `Cardio` weekly goal card.
     - `Body`: Add range selector (`1M | 3M | 1Y | All`), weekly rate, `Goal` & `+ Log` buttons, and `MORE` links (`Structural balance`, `Journal`).
     - `Lifts`: Add metric selector (`Top set`, `Est. 1RM`, `Volume`), range selector, recent sets RIR table, `Muscles` card (`Sets | Fatigue | Strength` tabs, `Completed | Planned` toggle, horizontal target range bars), and `Strength level` standards card.
     - `Effort`: Add `30d | 90d | 1Y | All` selector, average RIR headline, `Week by week` chart, and 5-bucket `Where the sets land` stacked bar (`RIR 0`..`RIR 4+`).
  3. **Exercises & Skill Ladders (`exercises_list_1.png`, `explore_muscles*.png`, `skill_ladders_1.png`–`7.png`):**
     - Add green best-weight badges, favourite star toggle, and `addToRoutineSheet` on `+` tap in `ExerciseLibraryScreen`.
     - Expand `SkillLaddersSheet` to all 7 built-in ladders (`Push-up`, `Pull-up`, `Dip`, `Squat`, `Hinge`, `Core`, `Handstand`), compute unlocked rungs from workout history, and add `+ Make your own ladder`.
  4. **Programmes, Measurements, History & Tools:**
     - Upgrade `ProgrammesScreen` to multi-week `%1RM` / `RPE` blocks + 3 starter programmes.
     - Expose all `BodyMeasurement` fields (`hipsCm`, `thighsCm`, `calvesCm`, `bpSys`, `bpDia`, `pulse`, `note`) in `MeasurementsScreen`.
     - Fix hardcoded `'kg'` in `WorkoutHistoryScreen` to use `controller.preferences.weightUnit`.
     - Add RPE Load table, DOTS/Wilks/IPF GL, BMI/FFMI/Navy Body Fat %, and Pace calculators to `ToolsScreen`.
- **Verification:** Widget and unit tests verifying `ActivityHeatmapWidget` `Time` vs `Volume` shading, 7 Skill Ladders progression detection, multi-week Programmes, and dynamic weight unit labels in `WorkoutHistoryScreen`.
