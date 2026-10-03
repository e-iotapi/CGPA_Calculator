# Pointer UI map

Legend: solid arrow = navigation, dashed arrow = sheet/dialog, triangle = inheritance. Tags: NEW, CHANGED, REMOVED = build; DEFERRED = do not build; untagged = exists on staging, do not touch.

Source: the design artifact's UML map (private). Mermaid `classDiagram`/`flowchart` blocks, verbatim.


## How to read the UML

```mermaid
classDiagram
  direction LR
  class Page {
    <<template>>
    icon Back · returns to the previous screen
    header Eyebrow and title
  }
  class Sheet {
    <<template>>
    icon Close
    swipe down · dismisses
  }
  class Dialog {
    <<template>>
    button Cancel or Keep · dismisses
    button Confirm action
  }
  class StaffPage {
    <<template>>
    pill Back to Pointer → Home
    strip Working as · Student → Home
  }
  Page <|-- StaffPage
  
```


## 1 · Start and Home

```mermaid
classDiagram
  direction LR
  classDef upd fill:#d9efe4,stroke:#2c7a62,stroke-width:2px
  classDef new fill:#e7defa,stroke:#6d3fd6,stroke-width:2px
  classDef stub fill:#1b1d17,stroke:#1b1d17,color:#ffffff
  class SignIn {
    <<screen>>
    button Continue with Google
  }
  class DegreeSetup {
    <<screen>>
    pills Campus · only when the address has none
    field Batch year · only when the address has none
    pills Single degree · Dual degree
    pill 2+2 · shows a not-ready notice
    row Your programme → ProgrammePick
    row Discipline · dual only → ProgrammePick
    button Set up → ErpImport
  }
  class ProgrammePick {
    <<screen>>
    field Code or name · filters the list
    row Programme · returns the choice
  }
  class ErpImport {
    <<screen>>
    pill Open ERP · opens the ERP site
    filepicker Performance sheet PDF → ImportPreview
    button Install · setup only → InstallGuide
    link Skip, I will enter grades myself → Home
    dialog Degree differs · Cancel · OK · Use it
  }
  class ImportPreview {
    <<sheet>>
    button Import → Home
    link Cancel
  }
  class InstallGuide {
    <<sheet>>
    button Got it
  }
  class Home {
    <<screen · updated>>
    icon Calendar → Calendar
    icon Stats → Stats
    icon Theme · toggles light and dark
    icon Settings → Settings
    tabs Actual · Expected · Compare · on this screen
    tab Offshoot → Offshoot
    tab More → More
    swipe · next or previous profile
    pull and hold · Clear grades dialog
    pills Semester · arrows when the row overflows
    cards Compare slots · Compare with sheet
    pill Add → AddCourse
    menu Sort · orders the courses
    icon Export gradesheet · saves an image
    drag Row handle · reorders
    row Course → Marks
    chip Grade · tap → GradeMenu · hold and drag for a wheel
    card Empty semester → AddCourse
    button Copy grades · Expected only · Import dialog
    NEW overlay Guided tour · first sign-in → Tour
  }
  class HomeNoOffshoot {
    <<state · new>>
    REMOVED tab Offshoot
    NEW More takes its slot
  }
  class Offshoot {
    <<tab of Home · updated>>
    pills Offshoot · Minor
    pills Best 5 · All 6 · scoring scale
    checkbox Course tile · counts it in the score
    row Minor card · Minor view · chooses a minor
    button Change · Minor view · minor list sheet
    button Stop pursuing · Minor view
  }
  class AddCourse {
    <<sheet · updated>>
    field Code or name · filters the catalogue
    row Result · selects it · CHANGED shows stars and review count
    dropdown Counts as · category sheet
    pills Grade · 14 options
    link Enter it manually · manual form
    field Manual · dept, number, title
    stepper Manual · credits
    button Add to semester · CHANGED no SGPA preview
    dialog Over the credit cap · Cancel · add anyway
  }
  class AddCourseRatingsOff {
    <<state · new>>
    NEW notice Ratings did not load · rows show no stars
  }
  class GradeMenu {
    <<popover>>
    pills A · A− · B · B− · C · C− · D · E
    pills NC · RC · W · GD
    pill Ongoing
    pill Not yet · clears the grade
  }
  class Tour {
    <<overlay · new>>
    40 steps in 7 chapters · see the tour map
  }
  class Marks
  class Calendar
  class Stats
  class Settings
  class More
  SignIn --> DegreeSetup : first sign-in
  SignIn --> Home : returning
  DegreeSetup --> ProgrammePick : programme row
  DegreeSetup --> ErpImport : Set up
  ErpImport ..> ImportPreview : PDF picked
  ErpImport ..> InstallGuide : Install
  ErpImport --> Home : Skip
  ImportPreview --> Home : Import
  Home ..> AddCourse : Add
  Home ..> GradeMenu : grade chip
  Home --> Offshoot : Offshoot tab
  Home ..> Tour : first sign-in
  Home --> Marks : course row
  Home --> Calendar : Calendar icon
  Home --> Stats : Stats icon
  Home --> Settings : Settings icon
  Home --> More : More tab
  Home <|-- HomeNoOffshoot
  AddCourse <|-- AddCourseRatingsOff
  cssClass "Home,Offshoot,AddCourse" upd
  cssClass "HomeNoOffshoot,AddCourseRatingsOff,Tour" new
  cssClass "Marks,Calendar,Stats,Settings,More" stub
  
```


## 2 · A course

```mermaid
classDiagram
  direction LR
  classDef upd fill:#d9efe4,stroke:#2c7a62,stroke-width:2px
  classDef new fill:#e7defa,stroke:#6d3fd6,stroke-width:2px
  classDef stub fill:#1b1d17,stroke:#1b1d17,color:#ffffff
  class Marks {
    <<screen · updated>>
    icon Edit scheme → SchemeEditor
    NEW icon Bin, beside Edit → DeleteCourse
    pill Taken by · Reviews → CourseReviews
    card Diverged · Keep my marks · Use official · CHANGED redesign, sits at the bottom of the screen; the full evaluative list takes its old place
    chip Course setup → CourseSetup
    row Averages → AverageSources
    card Evaluative → AddEvaluative
    icon Duplicate · copies the component
    row Use the official · reattaches one value
    button Add evaluative → AddEvaluative
  }
  class DeleteCourse {
    <<dialog · new>>
    button Keep
    button Delete · removes course and grades → Home
  }
  class SchemeEditor {
    <<screen · updated>>
    field Weight · per component
    field Class average · per component
    row Credits and grades → EditCourse · CHANGED was Credits, grades and delete
  }
  class EditCourse {
    <<sheet · updated>>
    row Counts as · category sheet
    pills Grade · Actual or Expected
    REMOVED button Remove · moved to the bin on Marks
    button Save
  }
  class CourseSetup {
    <<screen>>
    cards Weighted · Total marks
    field Course is marked out of · Total marks only
    pills Show it out of 100 · 200 · 300 · Custom
    field Custom scale
    field Class average
    button Save setup
    sheet Make it yours · Keep official · Make it mine
  }
  class AddEvaluative {
    <<screen · updated>>
    icon Delete component · edit only · confirm
    field Component name
    field Weight or Out of
    field Class average
    pills One mark · Several parts
    pills How many count · All · Best k of n
    field You · Out of · Date picker · single mark
    row Part · Date · You · Of · Avg · Name · Duplicate · Remove
    button Add a part
    button Add component or Save
    dialog Discard · Keep editing · Discard
    CHANGED Date, You, Out of, Avg labels one weight, smaller, regular
    CHANGED Part n, published average and LIVE tag: regular weight, one size
    text Averages fetched from the server
  }
  class AverageSources {
    <<screen>>
    row Course → CourseSetup
    row Component → AddEvaluative
    row Part → AddEvaluative
  }
  class CourseReviews
  class Home
  Marks ..> DeleteCourse : Bin
  DeleteCourse --> Home : Delete
  Marks --> SchemeEditor : Edit scheme
  Marks --> CourseSetup : setup chip
  Marks --> AverageSources : Averages row
  Marks --> AddEvaluative : card or Add evaluative
  Marks --> CourseReviews : Taken by pill
  SchemeEditor ..> EditCourse : Credits and grades
  AverageSources --> CourseSetup : Course row
  AverageSources --> AddEvaluative : Component row
  cssClass "Marks,SchemeEditor,EditCourse,AddEvaluative" upd
  cssClass "DeleteCourse" new
  cssClass "CourseReviews,Home" stub
  
```


## 3 · Calendar, Stats, Settings

```mermaid
classDiagram
  direction LR
  classDef upd fill:#d9efe4,stroke:#2c7a62,stroke-width:2px
  classDef new fill:#e7defa,stroke:#6d3fd6,stroke-width:2px
  classDef stub fill:#1b1d17,stroke:#1b1d17,color:#ffffff
  class Calendar {
    <<screen · updated>>
    NEW tabs Month · Week
    icon Previous month · Next month
    cell Day · selects the day
    link Show all · back to Next up
    row Event → Marks
    NEW academic calendar events shown by default
  }
  class CalendarWeek {
    <<state of Calendar · new>>
    NEW icon Previous week · Next week
    NEW link Today · jumps to this week
    NEW axis Time · hourly rows, 8 AM to 7 PM, scrolls for earlier or later
    NEW columns Mon to Sat · Sun only when it has events
    NEW line Now · across today's column
    NEW block Class · code, name, room, start and end time → ClassSheet
    NEW tag Your time · on a class whose time you changed
    NEW block Evaluative · quiz or exam at its time → Marks
    NEW strip All day · holidays and academic dates from the campus feed
    REMOVED cell Day grid
  }
  class ClassSheet {
    <<sheet · new>>
    NEW text Code, name, room, days and times
    NEW button Open course → Marks
    NEW button Change time, only for me · day and time pickers
    NEW link Reset to the published time · when changed
    NEW button Remove from my timetable · confirm dialog
  }
  class TimetablePlanner {
    <<state of CalendarWeek · deferred>>
    DEFERRED CDCs placed automatically · by degree and current semester
    DEFERRED panel Electives you can take · only those that clash with nothing
    DEFERRED row Elective · preview blocks on the grid · Add
    DEFERRED field Search electives
    DEFERRED button Finalise semester · the electives panel disappears
    DEFERRED reuses the week grid, class blocks and ClassSheet unchanged
  }
  class Stats {
    <<screen>>
    pills Progress · Degree · Minor, when chosen
    stepper Target CGPA · 4.00 to 10.00
    checkbox Forecast semester
    slider Planned SGPA
    card Credits earned · Credits your degree needs dialog
    card Category · expands
    dropdown Counts as · per course
    card Unassigned · expands
  }
  class Settings {
    <<screen · updated>>
    button Sign out
    row Working as · staff only → RoleSwitch
    row Contact details · staff only → RepProfile
    row Controls · admin only → AdminHome
    row Discipline → ProgrammePick
    row Dual degree → ProgrammePick
    choice Appearance · Light · Dark
    row Profile 1 · 2 · Compare · Name profile dialog
    row Install app → InstallGuide
    row Export grades · downloads CSV
    row Import grades from ERP → ErpImport
    row Import from old site · paste dialog
    button Report a bug · Report a problem dialog
    button Reset courses · confirm dialog
    link Email me · GitHub
    NEW row Academic calendar → CalendarFeed
    NEW switch Show Offshoot tab · on by default
    NEW row Replay the tour · whole tour or one chapter → Tour
    NEW row Become a contributor · hidden while applied or approved, back after a rejection → Apply
  }
  class CalendarFeed {
    <<sheet · new>>
    NEW switch Show the academic calendar in Pointer · on by default
    NEW button Copy feed link
    NEW button Add to Google Calendar
    NEW button Add to Apple or Outlook
  }
  class Marks
  class RoleSwitch
  class RepProfile
  class AdminHome
  class ProgrammePick
  class InstallGuide
  class ErpImport
  class Tour
  class Apply
  Calendar <|-- CalendarWeek
  CalendarWeek <|-- TimetablePlanner
  CalendarWeek ..> ClassSheet : class block
  ClassSheet --> Marks : Open course
  Calendar --> Marks : event row
  Settings --> RoleSwitch : Working as
  Settings --> RepProfile : Contact details
  Settings --> AdminHome : Controls
  Settings --> ProgrammePick : Discipline
  Settings ..> InstallGuide : Install app
  Settings --> ErpImport : Import grades from ERP
  Settings ..> CalendarFeed : Academic calendar
  Settings ..> Tour : Replay the tour
  Settings --> Apply : Become a contributor
  cssClass "Calendar,Settings" upd
  cssClass "CalendarWeek,CalendarFeed" new
  cssClass "Marks,RoleSwitch,RepProfile,AdminHome,ProgrammePick,InstallGuide,ErpImport,Tour,Apply" stub
  
```


## 4 · More, Representatives, Resources, Contributor

```mermaid
classDiagram
  direction LR
  classDef upd fill:#d9efe4,stroke:#2c7a62,stroke-width:2px
  classDef new fill:#e7defa,stroke:#6d3fd6,stroke-width:2px
  classDef stub fill:#1b1d17,stroke:#1b1d17,color:#ffffff
  class More {
    <<screen · updated>>
    card Representatives → Representatives
    card Course reviews → ReviewsHome
    card Resources → Resources
    NEW card Contributor Leaderboard · bigger, top 5 with your rank, shown to everyone → Leaderboard
  }
  class MoreContributor {
    <<state of More · new>>
    NEW card Contribute · appears when you apply → Contribute
    REMOVED card Contribute · when the application is rejected
  }
  class Representatives {
    <<screen · updated>>
    row Choose a campus · no campus → CampusPick
    pills Contact · Email · WhatsApp · Call
    icons Course contact · mail · chat · call
    pill Volunteer or Withdraw · course without a CR
    pill You are a CR · Edit → RepProfile
    row Message the public contact · owner-enabled
    CHANGED text Resources last updated Mon YYYY · per rep
  }
  class Resources {
    <<screen · rebuilt>>
    row Choose a campus · no campus → CampusPick
    NEW card Degree · one per degree → ResourceDegree
    NEW card Course resources → ResourceCourses
    pill Find your representatives · empty state → Representatives
    row Message the public contact · owner-enabled
    button Add a link · staff and contributors → LinkSheet
    REMOVED pills This semester · All · moved to Course resources
  }
  class ResourceDegree {
    <<screen · new>>
    row Link · opens the URL
    icon More options · Report sheet
    button Add a link · staff and contributors → LinkSheet
  }
  class ResourceCourses {
    <<screen · new>>
    NEW field Search a course · any degree
    NEW pills This semester · All
    NEW row Course → ResourceCourse
  }
  class ResourceCourse {
    <<screen · new>>
    NEW row Link · opens the URL
    NEW icon More options · Report sheet
    NEW pills CR contact · Email · WhatsApp · Call
    NEW text Last updated Mon YYYY · beside the CR
    NEW button Add a link · staff and contributors → LinkSheet
  }
  class ReportLink {
    <<sheet>>
    radio Reason
    field Add a note · optional
    button Send report
  }
  class LinkSheet {
    <<sheet · updated>>
    field Name
    field Link
    button Save
    CHANGED also opens from the student course page
  }
  class ContributorPrompt {
    <<sheet · new>>
    NEW button Not now
    NEW button Apply now → Apply
    NEW shown on the first Resources open each session
    NEW stops once applied · starts again after a rejection
  }
  class Apply {
    <<screen · new>>
    NEW text Rules · live now, approved within 15 days, points after approval
    NEW field Username · explained, shown on the leaderboard
    NEW error Username taken · inline under the field
    NEW button Apply → ContributePending
  }
  class ContributePending {
    <<state of Contribute · new>>
    NEW text Application sent · awaiting approval
    NEW pills President contact · Email opens mailto · WhatsApp · Call
    REMOVED button Add links · until approved
  }
  class Leaderboard {
    <<screen · new>>
    NEW rows Rank · username · branch tag · points
    NEW top 5 gold · silver · bronze · two soft purple, rank badges
    NEW row You · highlighted
  }
  class LeaderboardEmpty {
    <<state · new>>
    NEW text No contributors yet
  }
  class Contribute {
    <<screen · new>>
    NEW pills All · Awaiting · Approved · Rejected
    NEW row Link · state chip, reason when rejected → ContributeEdit
    NEW button Add links → ContributeAdd
    NEW text Points · counted after approval
  }
  class ContributeEmpty {
    <<state · new>>
    NEW text No links yet · Add links stays
  }
  class ContributeStaff {
    <<role variant · new>>
    CHANGED links publish directly, no approval states
  }
  class ContributeAdd {
    <<screen · new>>
    NEW pills Department · A course
    NEW dropdown Department · any on the campus
    NEW field Course search · any course
    NEW field Name · per link
    NEW field Link · per link
    NEW button Another link
    NEW button Publish · toast → Contribute
  }
  class ContributeEdit {
    <<screen · new>>
    NEW field Name
    NEW field Link
    NEW button Save · no delete
  }
  class ReviewsHome
  class CampusPick
  class RepProfile
  More <|-- MoreContributor
  Leaderboard <|-- LeaderboardEmpty
  Contribute <|-- ContributeEmpty
  Contribute <|-- ContributeStaff
  More --> Representatives : Representatives
  More --> ReviewsHome : Course reviews
  More --> Resources : Resources
  More --> Leaderboard : Leaderboard card
  MoreContributor --> Contribute : Contribute
  Resources --> ResourceDegree : degree card
  ResourceDegree ..> ReportLink : More options
  ResourceDegree ..> LinkSheet : Add a link
  Resources --> ResourceCourses : Course resources
  ResourceCourses --> ResourceCourse : course row
  ResourceCourse ..> ReportLink : More options
  Resources ..> LinkSheet : Add a link
  ResourceCourse ..> LinkSheet : Add a link
  Resources ..> ContributorPrompt : first open
  ContributorPrompt --> Apply : Apply now
  Apply --> ContributePending : Apply
  Contribute <|-- ContributePending
  Contribute --> ContributeAdd : Add links
  Contribute --> ContributeEdit : link row
  Representatives --> RepProfile : You are a CR
  cssClass "More,Representatives,Resources,LinkSheet" upd
  cssClass "MoreContributor,ResourceCourses,ResourceCourse,ContributorPrompt,Apply,ContributePending,Leaderboard,LeaderboardEmpty,Contribute,ContributeEmpty,ContributeStaff,ContributeAdd,ContributeEdit" new
  cssClass "ReviewsHome,CampusPick,RepProfile" stub
  
```


## 5 · Reviews and compulsory reviews

```mermaid
classDiagram
  direction LR
  classDef upd fill:#d9efe4,stroke:#2c7a62,stroke-width:2px
  classDef new fill:#e7defa,stroke:#6d3fd6,stroke-width:2px
  classDef stub fill:#1b1d17,stroke:#1b1d17,color:#ffffff
  class ReviewsHome {
    <<screen · updated>>
    tabs Courses · Your reviews
    field Course or professor · Courses tab
    row Professor → ProfessorReviews
    row Course → CourseReviews
    rows Your courses this semester · Most reviewed → CourseReviews
    row Choose a campus · no campus → CampusPick
    field Search your reviews · Your reviews tab
    CHANGED pills All, default · Helpful · Recent · Highest · Lowest · Your reviews tab
    row Your review → ReviewForm
  }
  class ReviewsLocked {
    <<state of Reviews · new>>
    NEW rule Needed = min of electives you have taken, and required, 5
    NEW applies only once 2-1 is complete · first year and 2-1 never locked
    NEW never locked when you have taken no electives
    NEW banner Reviews are locked · no count shown
    NEW button Review your electives → CompulsoryPick
    CHANGED search and course rows locked
  }
  class CourseReviews {
    <<screen · updated>>
    CHANGED dropdown Professor · search inside, empty allowed · was pills plus search
    CHANGED field Year · typed, validated · was pills
    CHANGED dropdown Semester · Sem 1 · Sem 2 · Summer · was pills
    CHANGED pills All · Helpful · Recent · Highest · Lowest
    field Search reviews
    CHANGED card Stats · follow the filters, no professor name
    NEW text Average grade and marks · marks only when shared
    NEW text Grade and marks on each review
    NEW icon Course resources → ResourceCourse
    button Helpful · per review, not your own
    button Report · per review, not your own
    link Clear filters
    link More reviews · next 10
    button Review this course or Edit your review → ReviewForm
  }
  class CourseReviewsNoMatch {
    <<state · new>>
    NEW text No reviews match
    link Clear filters
  }
  class ProfessorReviews {
    <<screen>>
    row Course taught → CourseReviews
  }
  class ReviewForm {
    <<screen · updated>>
    pills Professor · when the term had more than one
    stars Overall · 1 to 5
    pills Would you take it again · Yes · No
    field What should the next batch know · counter
    NEW dropdown Grade · Not disclosed allowed, prefilled
    NEW field Marks · optional, prefilled
    button Post review or Save changes
  }
  class CompulsoryPick {
    <<screen · new>>
    NEW checkbox Elective · last semester preselected
    NEW link Course name → ReviewForm
    NEW stars Overall · row 1
    NEW pills Would you take it · Yes · No · row 1
    NEW dropdown Grade · row 2
    NEW field Marks · row 2
    NEW field Add another elective · search
    NEW button Post N reviews · posts them all
    NEW unlocks once your posted reviews reach the needed number → Unlocked
  }
  class Unlocked {
    <<dialog · new>>
    NEW button Done → ReviewsHome
  }
  class CampusPick
  class ResourceCourse
  ReviewsHome <|-- ReviewsLocked
  CourseReviews <|-- CourseReviewsNoMatch
  ReviewsHome --> CourseReviews : course row
  ReviewsHome --> ProfessorReviews : professor row
  ReviewsHome --> ReviewForm : your review
  ReviewsHome --> CampusPick : Choose a campus
  ProfessorReviews --> CourseReviews : course row
  CourseReviews --> ReviewForm : Review or Edit
  CourseReviews --> ResourceCourse : resources icon
  ReviewsLocked --> CompulsoryPick : Review your electives
  CompulsoryPick --> ReviewForm : course name
  CompulsoryPick ..> Unlocked : Post N reviews
  Unlocked --> ReviewsHome : Done
  cssClass "ReviewsHome,CourseReviews,ReviewForm" upd
  cssClass "ReviewsLocked,CourseReviewsNoMatch,CompulsoryPick,Unlocked" new
  cssClass "CampusPick,ResourceCourse" stub
  
```


## 6 · Staff, shared screens

```mermaid
classDiagram
  direction LR
  classDef upd fill:#d9efe4,stroke:#2c7a62,stroke-width:2px
  classDef new fill:#e7defa,stroke:#6d3fd6,stroke-width:2px
  classDef stub fill:#1b1d17,stroke:#1b1d17,color:#ffffff
  class RoleSwitch {
    <<shared · O A P S CR EC · updated>>
    row Student → Home
    row Role and scope · one per grant → that role's home
    row Your contact details → RepProfile
    CHANGED rows stack · Elective Contributor listed as Electives
  }
  class RepProfile {
    <<shared · every appointed role>>
    button Sign out · first time only
    field Your name, as students see it
    field Phone number
    switch BITS email
    switch WhatsApp · with number field
    switch Phone call
    button Save and continue
  }
  class DeptHome {
    <<shared · P S EC · O A via Open as · updated>>
    row Course structures → DeptCourses
    row Resources → DeptResources
    row Reviews → DeptReviews
    row Professors → DeptProfessors
    row People → Roster
    row Hand over · not secretaries → Succession
    link Audit log → AuditLog
    NEW row Contributor approvals → Approvals
    NEW row Compulsory reviews → CompulsorySwitch
  }
  class DeptHomeElectives {
    <<role variant · new>>
    CHANGED label Electives where others show A3 or A7
    REMOVED row Hand over · until GEN has a successor flow
  }
  class DeptCourses {
    <<shared · P S EC · updated>>
    pill Choose a file → BulkUpload
    pill Paste · Paste JSON dialog → BulkUpload
    pill Copy · extraction prompt
    link Show or Hide prompt
    field Search courses
    link No scheme · All
    row Course → CourseScheme
    NEW pill Claim · GEN-prefix CDC, presidents → ClaimCourse
  }
  class DeptProfessors {
    <<shared · P S EC · updated>>
    field Search professors
    CHANGED button Add a professor · always enabled → ProfessorAdd
    row Professor · Rename dialog
    NEW icon Merge · in the pill → ProfessorMerge
    NEW icon Delete · in the pill → ProfessorDelete
    NEW group Removed · listed last
    card Merge two entries → ProfessorMerge
  }
  class ProfessorAdd {
    <<screen · new>>
    NEW field Name
    NEW rows Possible duplicates · tap to open instead
    NEW button Add or Add anyway
  }
  class ProfessorDelete {
    <<dialog · new>>
    NEW text Reviews stay under the name
    NEW button Keep · Delete
  }
  class ProfessorMerge {
    <<shared · P A O>>
    pills Campus · owner or admin
    row Department · department sheet
    row Possible duplicates · preselects both
    radio Professor · keep then merge
    button Merge into name
  }
  class DeptReviews {
    <<shared · P S EC>>
    pills All · Reported · Hidden
    pill Keep · clears reports
    pill Hide · reason dialog
    pill Unhide
  }
  class DeptResources {
    <<shared · P S EC>>
    pills Dept · By course · Reported
    button Add a link → LinkSheet
    row Link → LinkSheet
    link Unpin · rolled-up links
    icon Remove
    pill Fix the link → LinkSheet
    pill It works · dismisses reports
  }
  class CrHome {
    <<shared · CR P>>
    link Taken by · Change · Who teaches sheet
    link Evaluation scheme · Edit or Add → CourseScheme
    row Component → CourseScheme
    field Course average · Save
    link Course resources · Add → LinkSheet
    card Links reported · Open → DeptResources
    row Link → LinkSheet
    button Pick from department resources · sheet
  }
  class CourseScheme {
    <<shared · CR P S EC>>
    pills Percentages · Marks out of a total
    field Course out of · Graded out of · Course average
    field Component · Weight · Class average · Remove
    field Part · Out of · Avg · Date picker · Remove
    dropdown All count · Best k of n
    button Add a component
    button Save for everyone
  }
  class Roster {
    <<shared · P A O>>
    tabs Maintainers · Volunteers
    pills All · Presidents · CRs · Expiring
    row Person · owner or admin → Person
    button Appoint someone → Appoint
  }
  class Appoint {
    <<shared · P A O · updated>>
    field BITS student address
    pills Admin · President · Secretary · CR
    row Department · department sheet
    NEW row GEN · Electives · owner or admin, makes an Elective Contributor
    pills Programme · when the department has several
    field Course code · CR, with suggestions
    pills Expires · Full term · Earlier date picker
    link Grant terms → Terms
    button Grant
  }
  class AuditLog {
    <<shared · P A O>>
    row Actor · sheet
    field Course · with results
    pill Filter
    pill Course filter chip · clears
  }
  class Approvals {
    <<shared · P S EC A · new>>
    NEW tabs Applications · Links
    NEW button Approve all · top
    NEW row Application · Approve · Decline → Reason
    NEW row Link request · links open · Approve · Reject → Reason
    NEW row Contributor · Revoke → Revoke
  }
  class Reason {
    <<sheet · new>>
    NEW pills Reason presets
    NEW field Note · they see it
    NEW button Send
  }
  class Revoke {
    <<dialog · new>>
    NEW button Keep · Revoke
  }
  class CompulsorySwitch {
    <<shared · P S A O · new>>
    NEW pills Campus · admin or owner
    NEW switch Compulsory reviews → SwitchOn
    NEW text Turned on by, since
  }
  class SwitchOn {
    <<dialog · new>>
    NEW button Cancel · Switch on
  }
  class ClaimCourse {
    <<dialog · new>>
    NEW button Cancel · Claim
  }
  class Home
  class LinkSheet
  class AdminHome
  class Succession
  class BulkUpload
  class Person
  class Terms
  RoleSwitch --> Home : Student
  RoleSwitch --> DeptHome : department role
  RoleSwitch --> CrHome : course role
  RoleSwitch --> AdminHome : admin role
  RoleSwitch --> RepProfile : contact details
  DeptHome <|-- DeptHomeElectives
  DeptHome --> DeptCourses : Course structures
  DeptHome --> DeptResources : Resources
  DeptHome --> DeptReviews : Reviews
  DeptHome --> DeptProfessors : Professors
  DeptHome --> Roster : People
  DeptHome --> Succession : Hand over
  DeptHome --> AuditLog : Audit log
  DeptHome --> Approvals : Contributor approvals
  DeptHome --> CompulsorySwitch : Compulsory reviews
  DeptCourses --> BulkUpload : file or paste
  DeptCourses --> CourseScheme : course row
  DeptCourses ..> ClaimCourse : Claim
  DeptProfessors --> ProfessorAdd : Add a professor
  DeptProfessors ..> ProfessorDelete : Delete icon
  DeptProfessors --> ProfessorMerge : Merge icon
  DeptResources ..> LinkSheet : Add or fix
  CrHome --> CourseScheme : scheme
  CrHome ..> LinkSheet : Add
  CrHome --> DeptResources : Links reported
  Roster --> Person : person row
  Roster --> Appoint : Appoint someone
  Appoint --> Terms : Grant terms
  Approvals ..> Reason : Decline or Reject
  Approvals ..> Revoke : Revoke
  CompulsorySwitch ..> SwitchOn : switch on
  cssClass "RoleSwitch,DeptHome,DeptCourses,DeptProfessors,Appoint" upd
  cssClass "DeptHomeElectives,ProfessorAdd,ProfessorDelete,Approvals,Reason,Revoke,CompulsorySwitch,SwitchOn,ClaimCourse" new
  cssClass "Home,LinkSheet,AdminHome,Succession,BulkUpload,Person,Terms" stub
  
```


## 7 · Staff, role-only screens

```mermaid
classDiagram
  direction LR
  classDef upd fill:#d9efe4,stroke:#2c7a62,stroke-width:2px
  classDef new fill:#e7defa,stroke:#6d3fd6,stroke-width:2px
  classDef stub fill:#1b1d17,stroke:#1b1d17,color:#ffffff
  class AdminHome {
    <<O A · president sees a subset · updated>>
    row Maintainers → People
    row Appoint someone → Appoint
    row Roster → Roster
    row Grant terms → Terms
    row Public contact → PublicContact
    row Merge professors → ProfessorMerge
    row Audit log → AuditLog
    row Owners · owner → Owners
    row Publish catalogue · owner → Publish
    row Open Pointer as · owner → OpenAs
    row Site analytics · owner → Analytics
    NEW row Contributor approvals → Approvals
    NEW row Compulsory reviews → CompulsorySwitch
  }
  class People {
    <<O A>>
    pills All · Goa · Hyd · Pilani · Dubai · Expiring
    row Grant → Person
    button Appoint someone → Appoint
  }
  class Person {
    <<O A P>>
    button Revoke · confirm dialog
  }
  class Terms {
    <<O A>>
    stepper CR semesters · President years · Admin years, owner
    button Save grant terms
  }
  class PublicContact {
    <<O A>>
    switch Show on empty pages
    field Name on the button
    pills WhatsApp · Phone · Email
    field Number or address
    button Save
  }
  class Owners {
    <<O>>
    pill Remove or Restore · per owner
    field Email
    field Name
    button Add owner
  }
  class Publish {
    <<O>>
    row Titles and default tags · expands
    checkbox I have read the credit changes
    pill Draft a change · draft sheet with code, title, credits, retired
    button Publish N changes · confirm dialog
  }
  class Analytics {
    <<O>>
    pills All campuses · Goa · Hyderabad · Pilani · Dubai
  }
  class OpenAs {
    <<O>>
    row Owner → AdminHome
    row Admin → AdminHome
    row Department president → ViewAsDept
    row Course manager → ViewAsCourse
    row Student → Home
  }
  class ViewAsDept {
    <<O>>
    pills Campus
    field Dept or programme
    row Department → DeptHome
  }
  class ViewAsCourse {
    <<O>>
    pills Campus
    field Code or professor
    row Course → CrHome
  }
  class OwnerSetup {
    <<O · first sign-in, non-BITS>>
    pills Campus
    field Batch
    button Continue → Home
  }
  class CampusPick {
    <<O · preview campus>>
    row Campus · saves on this device
  }
  class Succession {
    <<P only>>
    field Their BITS address
    field Next secretary · optional
    button Review the handover → SuccessionConfirm
    button Cancel the handover · when one is open
  }
  class SuccessionConfirm {
    <<P only>>
    field Department code · must match
    button Hand over → DeptHome
    link Not yet
  }
  class Volunteers {
    <<P only · tab of Roster>>
    row Department · department sheet
    icon Copy notice
    pill Appoint as CR → Appoint
    pill Dismiss
  }
  class BulkUpload {
    <<P S EC>>
    button Write N schemes · confirm dialog
  }
  class Appoint
  class Roster
  class ProfessorMerge
  class AuditLog
  class Approvals
  class CompulsorySwitch
  class DeptHome
  class CrHome
  class Home
  AdminHome --> People
  AdminHome --> Appoint
  AdminHome --> Roster
  AdminHome --> Terms
  AdminHome --> PublicContact
  AdminHome --> ProfessorMerge
  AdminHome --> AuditLog
  AdminHome --> Owners
  AdminHome --> Publish
  AdminHome --> OpenAs
  AdminHome --> Analytics
  AdminHome --> Approvals
  AdminHome --> CompulsorySwitch
  People --> Person : grant row
  People --> Appoint : Appoint someone
  OpenAs --> ViewAsDept : Department president
  OpenAs --> ViewAsCourse : Course manager
  ViewAsDept --> DeptHome : department
  ViewAsCourse --> CrHome : course
  Roster --> Volunteers : Volunteers tab
  Volunteers --> Appoint : Appoint as CR
  Succession --> SuccessionConfirm : Review the handover
  SuccessionConfirm --> DeptHome : Hand over
  OwnerSetup --> Home : Continue
  cssClass "AdminHome" upd
  cssClass "Appoint,Roster,ProfessorMerge,AuditLog,Approvals,CompulsorySwitch,DeptHome,CrHome,Home" stub
  
```


## 8 · Guided tour

```mermaid
flowchart TB
  classDef new fill:#e7defa,stroke:#6d3fd6,stroke-width:2px,color:#25124f
  subgraph C1["Chapter 1 · Home basics · on Home"]
    direction LR
    T1["1 · Actual tab<br/><i>Your real grades. SGPA and CGPA update as you set them</i>"]:::new
    T2["2 · Swipe sideways<br/><i>Move between Actual, Expected and Compare</i>"]:::new
    T3["3 · Semester pills<br/><i>Pick a semester; the arrows scroll on a computer</i>"]:::new
    T4["4 · Grade chip, tap<br/><i>Tap a grade to change it</i>"]:::new
    T5["5 · Grade chip, hold and drag<br/><i>Hold and drag up or down to scrub through grades</i>"]:::new
    T6["6 · Add<br/><i>Add a course from the catalogue, with its star ratings, or enter one by hand</i>"]:::new
    T7["7 · Sort menu and drag handle<br/><i>Sort your courses, or drag the handle into your own order</i>"]:::new
    T8["8 · Pull down and hold<br/><i>Pull down and hold to clear this semester's grades</i>"]:::new
    T9["9 · Export gradesheet<br/><i>Save this semester's grades as an image</i>"]:::new
    T1 --> T2 --> T3 --> T4 --> T5 --> T6 --> T7 --> T8 --> T9
  end
  subgraph C2["Chapter 2 · Grade profiles"]
    direction LR
    T10["10 · Expected tab<br/><i>The grades you expect, to plan the semester</i>"]:::new
    T11["11 · Copy grades button<br/><i>Start Expected from your Actual grades in one tap</i>"]:::new
    T12["12 · Compare tab<br/><i>Two profiles side by side; tap a card to pick which</i>"]:::new
    T10 --> T11 --> T12
  end
  T9 --> T10
  subgraph C3["Chapter 3 · Marks tracker · opens your first course, skipped if you have none"]
    direction LR
    T13["13 · Course row<br/><i>Tap a course to track its marks</i>"]:::new
    T14["14 · Course setup chip<br/><i>Weighted, each part has a %, or total marks, and what it is out of</i>"]:::new
    T15["15 · Add evaluative<br/><i>Add each quiz, midsem, lab or compre: weight, your marks, out of, date</i>"]:::new
    T16["16 · Several parts, best k of n<br/><i>Split a component into parts and count only the best k</i>"]:::new
    T17["17 · Class average and Averages row<br/><i>Add the class average to see where you stand; tap to see where each average came from</i>"]:::new
    T18["18 · Official scheme<br/><i>When your CR publishes the scheme, weights and averages fill in by themselves</i>"]:::new
    T19["19 · Divergence card<br/><i>Change an official value and we keep yours, and show what changed</i>"]:::new
    T20["20 · Edit and bin icons<br/><i>Edit the scheme, credits and grade, or delete the course</i>"]:::new
    T21["21 · Taken by, Reviews<br/><i>See who teaches it this term and what past batches said</i>"]:::new
    T13 --> T14 --> T15 --> T16 --> T17 --> T18 --> T19 --> T20 --> T21
  end
  T12 --> T13
  subgraph C4["Chapter 4 · Offshoot and Minor"]
    direction LR
    T22["22 · Offshoot tab<br/><i>Your offshoot score: best 5 or all 6, tick the courses that count</i>"]:::new
    T23["23 · Minor toggle<br/><i>Choose a minor and see what it still needs</i>"]:::new
    T22 --> T23
  end
  T21 --> T22
  subgraph C5["Chapter 5 · Calendar and Stats"]
    direction LR
    T24["24 · Calendar icon<br/><i>Your evaluatives and the academic calendar, by month</i>"]:::new
    T25["25 · Week tab<br/><i>Your classes by time; tap one to change its time just for you</i>"]:::new
    T26["26 · Stats icon<br/><i>Your CGPA, semester by semester</i>"]:::new
    T27["27 · Target CGPA<br/><i>Set a target and see the SGPA you need</i>"]:::new
    T28["28 · Plan the rest<br/><i>Slide each future semester to plan your way there</i>"]:::new
    T29["29 · Degree tab<br/><i>Credits earned for each requirement; change what a course counts as</i>"]:::new
    T24 --> T25 --> T26 --> T27 --> T28 --> T29
  end
  T23 --> T24
  subgraph C6["Chapter 6 · More"]
    direction LR
    T30["30 · More tab<br/><i>Everything beyond your grades</i>"]:::new
    T31["31 · Representatives<br/><i>Your president and each course's CR, with contacts; volunteer to be a CR</i>"]:::new
    T32["32 · Course reviews<br/><i>Search a course or professor; filter by professor, year and semester</i>"]:::new
    T33["33 · Resources<br/><i>Department and course links: notes, papers, handouts</i>"]:::new
    T34["34 · Contributor Leaderboard<br/><i>The top contributors on campus; apply to join from Resources or Settings</i>"]:::new
    T30 --> T31 --> T32 --> T33 --> T34
  end
  T29 --> T30
  subgraph C7["Chapter 7 · Settings · last chapter"]
    direction LR
    T35["35 · Settings icon<br/><i>Your degree, grade profiles, data and the app</i>"]:::new
    T36["36 · Grade profiles rows<br/><i>Rename Actual, Expected and Compare</i>"]:::new
    T37["37 · Import grades from ERP<br/><i>Fill past semesters from your ERP performance sheet</i>"]:::new
    T38["38 · Appearance and Show Offshoot tab<br/><i>Light or dark, and hide the Offshoot tab if you do not need it</i>"]:::new
    T39["39 · Install app<br/><i>Add Pointer to your home screen</i>"]:::new
    T40["40 · Replay the tour<br/><i>Run this again, or one chapter, any time · Done</i>"]:::new
    T35 --> T36 --> T37 --> T38 --> T39 --> T40
  end
  T34 --> T35
  
```


## 9 · Boards that go away


## 10 · States and variants


## 11 · Before I rebuild
