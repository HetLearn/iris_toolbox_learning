# Rulebook for writing economics papers with Tolga

Version 9, 23 October 2026 (section 7: figure font, house style, outcomes the paper follows; results driven by a
few economies are shown with a marker, not hidden). Distilled from:
- the ADPR background paper iterations (shock reports, paper_v2 to paper_v6);
- two reviews of paper_v6 (an external review and a Fable review of AI-sounding prose), in
  `Desktop\poverty_and_income\paper_v6\notes\` (`astra_review.md`, `ai_style_review.md`);
- the public guides on AI-sounding prose, harmonized in section 11. Sources: Wikipedia's "Signs of AI writing",
  the humanizer and stop-slop skills, the slop-forensics/Antislop word lists, Kobak et al. (2025) and Liang et al.
  (2024) on LLM vocabulary in science, and the classic economics guides by Cochrane (2005) and McCloskey (2019).
  Evidence in `AI_WRITING_TELLS_REVIEW.md` (same folder).

Use it for every paper, background note, slide deck and report. A project-specific instruction wins over a rule here.
When the user changes a rule, update this file, and the index in `README.md` (same folder, the central rulebook
library).

## 1. Voice and vocabulary
- Write like a published applied macro paper: plain, direct, natural. Short sentences, active voice, no padding.
- Do not talk to the reader. No second person ("you bring a model file", "the variables you choose", "your
  scenario"): describe what the paper, method or tool does ("the toolbox takes a model file and a database"). The
  user finds the instructional you-voice condescending. This holds for web pages and project descriptions too
  (user rule, 22 October 2026).
- Use the literature's standard terms. Never coin labels for our own constructs ("sign-flipped SOI", "focus shocks"
  as a category, "episode-scaled layer"). If a step needs explaining, explain it in words: "we flip the sign of the
  SOI so that a positive value is an El Nino year".
- Avoid terms that sound technical without need. If a simpler word works, use it.
- Keep the user's chosen labels once set (for example "welfare gap"). Do not rename variables between drafts.
- One name per thing, kept throughout (McCloskey): no synonyms for variety.
- Describe inputs as what they are. Heterogeneous series (announcement surprises, statistical innovations, price
  changes, crisis dates) are "shock series", not "identified shocks", unless the identification of each is defended.
- Spell out abbreviations on first use and avoid unexplained ones in figures and tables ("Latin America and the
  Caribbean", not "LAC"). Labels say what the variable is and give its unit ("Reserves (months of imports)").
- ADB style for economy names (the People's Republic of China; Hong Kong, China; Taipei,China; Viet Nam).
- US spelling throughout, including text inside figures and legends ("favorable", "color", "labeled").
- No em dashes. Section 11 lists the patterns that make prose read as machine-made.
- Keep the plain, direct sentences that work ("The data are annual."). Consistent terms and qualified claims matter
  more than swapping synonyms.
- Cite our own work by the title the user gave. Titles, author lists and report years taken from agendas or other
  documents are unconfirmed until the user says so: leave a placeholder and flag it.
- Once the user confirms the authors, they appear in every later draft, version and talk of that work. Never drop
  them or revert to a placeholder.
- ADB work carries the authors' affiliation (Asian Development Bank) under the author line, and the standard ADB
  disclaimer at the foot of the title page. A talk's title slide carries the affiliation and the one-sentence views
  disclaimer. The standard wording, with "paper" for "publication":
  - "The views expressed in this paper are those of the authors and do not necessarily reflect the views and
    policies of the Asian Development Bank (ADB) or its Board of Governors or the governments they represent."
  - "ADB does not guarantee the accuracy of the data included in this paper and accepts no responsibility for any
    consequence of their use."
  - "The mention of specific companies or products of manufacturers does not imply that they are endorsed or
    recommended by ADB in preference to others of a similar nature that are not mentioned."
  - "By making any designation of or reference to a particular territory or geographic area, or by using the term
    'country' in this paper, ADB does not intend to make any judgments as to the legal or other status of any
    territory or area."
- Titles: propose plain, descriptive ones without abstract metaphors. The user decides.

## 2. Structure and length
- Concise and succinct everywhere. A section earns its length through content, not coverage.
- Fit the family: background papers for the same report should look and read alike (layout, length, tone).
- Connect to the parent report's theme (for the ADPR: resilience) in the introduction, the results and the
  conclusion, even when the paper has no dedicated resilience measure.
- Order: introduction, literature, data, empirical strategy, results, what amplifies the effects, caveats,
  conclusion, appendices.
- Say each thing once, in its place. The introduction previews the central finding, the results develop it and the
  conclusion draws its implications. Do not restate the same lesson in several sections.
- No refrains. A sentence longer than eight words appears only once in the paper. The abstract, the introduction,
  the results and the conclusion state a main result each with a different subject and at least one different detail.
  Check with a duplicate-sentence search before delivery.
- One "what we add" passage per paper (introduction or end of the literature review, not both).
- Counting scaffolds ("three findings", "three things", "three questions", "three lessons"): at most one per paper,
  and "First/Second/Third" at most once. Lists of two, four or five are fine when that is the count. Signpost only
  where it helps navigation; a one-sentence roadmap at most.
- Define each unit or construct once, where it is first used ("per onset", the welfare gap), and refer to it by name
  afterward.
- Do not inventory in prose what a table lists: one summary sentence and a pointer to the table.
- Numbers that appear in several places (sample sizes, years, horizons) must agree.
- Papers that introduce software (a toolbox, a package, a model kit) are about the approach, what the tool can do,
  the gap it fills and who needs it, shown with worked examples. No code in the paper: no listings, function, option
  or file names, syntax, folder paths, test counts or commit hashes. Describe each capability in economic terms. Say
  once, early, that the code, option reference, examples and reproduction scripts are in the repository, and repeat
  it in the code availability statement (user rule, 22 October 2026).

## 3. Introduction and literature review
- State the question, why it matters to the parent report's reader, and the one central contribution in the first
  paragraphs (Cochrane). State the main findings early, in words, with at most one or two numbers.
- Organize the literature review by the question (transmission; distributional and welfare effects; exposure), not
  by paper. Cite only verified references (DOI or publisher page checked).
- Make it argue. Build each strand around a disagreement or open question: where findings differ, what the measures
  capture differently (e.g., Gini coefficients vs income shares), what remains unreconciled, and how our evidence
  speaks to it. Back every proposed explanation with the cited studies. No catalogues of "A finds X; B finds Y".
- Each subsection has at least one sentence of judgment: why two studies disagree, or which design is closest to
  ours and how ours differs. At most one bare "finding, citation" sentence in three.
- Hedges resolve. When literatures disagree, say which side our design and data put us on. "Single-shock studies
  offer more detail; our aim is comparability" is not a position.

## 4. Data
- Tables list what the reader needs. For shocks: shock, source, scope and coverage. For variables: variable, source
  and broad coverage. No mnemonics, no country-specific exceptions, no "purpose" column, short notes.
- Describe each shock in a few sentences: what it is, how it is built, its unit. Construction details go in the
  appendix.
- Explain units plainly before the results: "per one standard deviation of the shock" and, for crises, "the effect of
  the start of a crisis, compared with what would otherwise have happened".
- Define measures we construct (for example the welfare gap) where they are first used in the results, with the
  reference they come from, not in the data section.

## 5. Empirical strategy
- Short: the estimating equation, the controls in one sentence, inference in one sentence. Everything else in the
  appendix, where equations can be as long as needed.

## 6. Results
- Lead with the finding; cite the exhibit in parentheses: "Bottom-40 income falls by more than GDP (Figure 3)", not
  "Figure 3 shows...".
- Messages first, numbers second. Discuss results qualitatively; quote a few key magnitudes (GDP, unemployment,
  inflation) and never list every coefficient or precise differences.
- Use a small number of cases to show the dynamics and say why they were chosen (for example, two shocks with
  contrasting transmission). Do not formalize the choice into categories.
- Separate overall economic damage (GDP per capita, jobs, prices) from who bears it (the poorest 40 percent, the
  welfare gap). A shock can do the most damage overall without hurting the poor disproportionately.
- Always discuss persistence: how long the effects last.
- Match claims to the estimates: "no statistically significant effect", not "no effect"; insignificance is not
  harmlessness. The abstract and conclusion keep the qualifications that the results make.
- Summaries keep the exceptions. Prefer the faithful pattern to a neat symmetric contrast.
- Separate what is estimated (responses, differences across economies) from interpretation (mechanisms). Unless a
  channel is identified, present it as an explanation that helps account for the results.
- Rank by what is estimated with some precision. A result significant only at 68 percent is "less precisely
  estimated"; do not group it with clearly significant ones without saying so.
- Significance: ** 95 percent, * 90 percent, dagger (†) 68 percent. Never use * for 68 percent.
- Counterintuitive or puzzling results: investigate before presenting. Say what was checked and what it showed; if
  the puzzle remains, say so directly and connect it to the relevant data issue (e.g., imputation). The model passage
  names the episode, reports the check and says how the estimate changes.
- Define selection rules where they are used. Example: a "top amplifier" is the most statistically significant
  adverse interaction, not necessarily the largest effect.
- Category labels must not presuppose the direction of an effect: high private credit or debt is exposure, not a
  "buffer".
- In heterogeneity sections, discuss the few relationships that carry the argument. The figure and the appendix hold
  the full set.
- Use the parent report's definitions verbatim where they exist (the ADPR's definition of resilience) and map our
  outcomes onto them: depth of the loss, its persistence (recovery), who bears it.
- Results carry the estimator's voice. Each results subsection has at least one sentence only the authors could
  write: a check that was run, a case that drives a result, a result that surprised us, a result still in doubt.
  Anticipate the obvious reader question (for example, why a well-known episode is not among the largest shocks).
- "This fits / is consistent with the evidence" at most once per section, and then with a magnitude or a specific
  study.
- Horizon labels are defined once and never shared. For example, h = 3 is "four years", h = 7 is "eight years" and
  h = 8 is "the end of the horizon".

## 7. Figures and tables
- Figures over tables in the main text. Captions short: a title and one line of notes at most.
- No titles inside figures in a paper (the LaTeX caption carries the title); panel titles are fine. Figure text
  follows the same vocabulary rules as the prose: no internal tags or made-up terms.
- Groups and regions: full names, no unexplained abbreviations. Use subregions only where each has enough economies
  (at least 10 in a regression); otherwise use regions.
- No diagnostics in the main text. Robustness checks appear as overlaid lines or in the appendix.
- Never hide a result in a way that makes a figure look broken (impulse responses cut off midway). If a rule hides
  it, overrule the rule or explain it in one sentence.
- Do not suppress a result because one or a few economies drive it. Show it, with a marker explained once in the
  note (for example "‡ driven by one to three economies"), and let the reader judge. This applies to every exhibit,
  including the choice of a "top" characteristic or region.
- Consistent signs: choose signs so that "up" means the same thing (worse for the poor) across related measures, and
  say it once.
- Keep what works in our figures: units in every panel subtitle, honest labels for suppressed results, and one
  legend convention across all figures.
- Exhibits show what the user asked for. Do not add variables, panels or outcomes on your own initiative (for
  example, an unemployment panel in an all-shocks GDP figure). Propose them instead.
- Fonts must be readable at the printed size: at least 8 pt for ticks and legends, and about 9 to 10 pt for labels
  and panel titles at the final width. When a figure gets dense, split it into several figures by group (for
  example, one per shock group) rather than shrinking the fonts.
- Each figure and table appears in the section that discusses it, after the paragraph that first cites it, and
  never above its section heading. In LaTeX: `placeins` with `[section]` plus `flafter`, and the float environment
  placed right after the first citing paragraph. Check the page of each float against the page of its first
  citation before handover.
- Figures are set in the document's own text font (for a LaTeX paper, the font of its font package, loaded from the
  TeX installation). Never matplotlib's default DejaVu Sans or another stock font: readers recognize those as
  machine-made.
- One house style per document, defined once in a shared style module that every figure script imports: font, sizes
  and a small named palette. No stock palettes (library defaults, teal and brown, red and green), no green accents,
  no hatching, no legend frames, no top, right or left spines; a light horizontal grid; direct labels where there is
  room. A basic-looking figure is a defect, not a matter of taste.
- An exhibit carries only outcomes the paper follows through its argument. If a variable is discussed nowhere else,
  drop its panel and its discussion rather than keeping it as context.

## 8. Caveats and conclusion
- Caveats are honest and few: data frequency, data quality (imputed welfare data, often where it matters most), the
  common standardization of shocks, identification limits. They are not a list of every flaw and do not trash the
  paper.
- Put a caveat next to the finding it qualifies (e.g., correlated characteristics next to the amplifier results),
  not only in the caveats section.
- The conclusion does not recap the introduction.
  - It develops the implication that follows most directly from the evidence (e.g., tracking aggregate recovery can
    miss a persistent deterioration for the poor) and links it to the parent report's theme.
  - It names two or three extensions, ranked by how much each would change our confidence in the central finding,
    and says why.
  - It adds at least one thing the introduction did not say (a qualification, a number, a policy instrument, a
    remaining doubt) and does not reuse the introduction's ordering.

## 9. Appendix
- Short text, short tables, no information the reader does not need. Equations are welcome here.
- Full results tables can be listed without discussion: say they are the full set from which the main text picks.

## 10. Slides
- Simple, clean academic style that does not look machine-made: white background, one font, no colored boxes, no
  icons, no "key takeaways" cards, few words per slide, one message per slide in the title.
- A 20-minute talk is about 12 to 15 slides. Use slide-specific figures (subsets of shocks or variables), not copies
  of the paper's dense figures.
- LaTeX (beamer) for academic talks; pptx when matching an institutional template.

## 11. Prose that reads as machine-made
The tell is accumulation, not any single sign: several patterns stacking up across a document (Wikipedia, "Signs of
AI writing"). Audit the whole draft, worst offenders first. The rules below merge the sources; where they conflict,
the version suited to academic economics prose wins.

**A. Whole-document patterns** (check first)
- Repeated explanatory structure: the same contrast or lesson restated in the abstract, introduction, several results
  passages and the conclusion. Consolidate (section 2).
- Counting scaffolds and symmetric outlines: "three findings / three lessons", sections built on the same template,
  paragraphs that all end with a recap line.
- Neat symmetry that drops the exceptions. A tidy two-sided story reads as generated and is usually less accurate.
- Describing the document instead of the subject: "Table 2 shows", "In this section we discuss", a first sentence
  that restates the heading, section-ending summaries.
- A conclusion that echoes the introduction sentence by sentence.

**B. Sentence patterns**
- Contrast scaffolds: "not X but Y", "X, yet Y", "rather than", "not only... but also", "A does X; B does Y". Use
  one only against a view someone actually holds: at most one per paragraph and two in the abstract. The paper's
  central contrast is stated as a contrast once in the results and once in the conclusion. This is the
  heaviest-weighted tell in the data-driven lists.
- Summary closers. A paragraph does not end with a "thus/therefore/so" sentence that restates its opening; it ends
  on its last piece of evidence or on the next question. "Thus" and "therefore" at most once per page.
- Role-announcing openers. Consecutive paragraphs do not open by announcing their role ("X follows a different
  pattern", "Y gives a second view", "Some regularities hold"). Open with the finding or the object.
- Colon lists ("X: a, b and c"): at most one per page.
- Habitual threes: list as many items as the content has.
- Significance riders: trailing "-ing" clauses that add importance rather than facts ("..., highlighting the
  importance of", "underscoring", "reflecting a broader"). Delete; if the sentence still works, it was filler.
- Staged run-ups and recap closers: "The key point is", "Here is the thing", "In short", a last line restating the
  paragraph.
- Aphorisms and overclaims: memorable lines that say more than the design shows ("the channel decides who bears the
  loss"). A memorable line that is accurate appears once, not in the introduction and the conclusion as well.
- Arguing with no one: rebutting objections nobody raised.
- Repeated openings and metronomic rhythm: consecutive sentences starting the same way, or every sentence of similar
  length. As a check:
  - each section has at least one sentence under eight words and one over thirty-five;
  - no paragraph has every sentence between 15 and 25 words;
  - paragraph length follows importance, so parallel paragraphs are not all the same length.
- Stacked hedges ("could potentially", "may possibly"): hedge once, at the claim that is uncertain, and say why.
- Missing actors: passive voice is fine for data and methods. Name the actor when who did something matters ("we
  exclude", "the authorities intervene").

**C. Words and phrases.** Flag them and replace them with the plain word or a specific claim. The lists drift as
models change, so treat them as flags, not bans.
- LLM-inflated vocabulary (Kobak et al.; Liang et al.; slop lists): delve, underscore, showcase, pivotal, intricate,
  realm, meticulous, commendable, notably, crucial, comprehensive, enhance, insights, additionally, landscape,
  nuanced, multifaceted, holistic, seamless, foster, tapestry, testament, navigate (figurative), leverage (as a verb),
  robust (outside its econometric meaning).
- Academic stock phrases: "a growing body of literature", "sheds light on", "paves the way", "plays a
  crucial/pivotal/key role", "it is worth noting", "it is important to note", "in recent years", "to the best of our
  knowledge", "further research is needed", "has garnered attention".
- Avoided copulas: "serves as", "stands as", "boasts", "features". Write "is" and "has".
- Vague links and borrowed authority: "is associated with" when the relation is known, "experts argue", "studies
  show" without a citation.
- Word budget. Rhetorical adverbs and stock phrases ("sharply", "clearly", "disproportionately", "stands out",
  "broadly shared", "those least able to absorb them") appear at most twice per paper. Technical terms stay fixed. A
  paper's central abstractions ("overall damage", "the losses of the poor") alternate with their concrete referents
  (GDP per capita, bottom-40 income).

**D. What makes economics prose read as written by a person** (the positive rules)
- Specifics only the authors know: the episode behind an estimate (Bulgaria 1996-97), the check that changed a
  result, the reason for a choice, a surprise, a doubt that remains.
- Judgment in the literature review: which papers matter for our question, and why.
- Claims qualified exactly as much as the evidence requires, no more and no less.
- "We" for our choices; the literature's terms; one name per thing.

**E. Process**
- Two passes. Draft; then audit against A to D and revise. Re-read the revision for tells it introduced: swapping one
  flag word for another fixes nothing.
- Optional score (stop-slop rubric): directness, rhythm, trust in the reader, authenticity, density, 1-10 each.
  Revise below 35/50.
- Do not over-sanitize. Zero dashes, zero repetition and evenly sprinkled "imperfections" are a formula too.
- Before handover, a Fable review (section 12). Never send unpublished drafts to online detectors. Detector scores
  are unreliable on formal prose and are not a target.

**F. Rules from the sources we do not adopt, and why**
- Bans on all adverbs, all passive voice and Wh- sentence openings (stop-slop): too blunt for academic prose. In data
  and methods the passive is standard, and adverbs such as "roughly" or "only" carry meaning. Covered instead by B.
- "Two items instead of three" (stop-slop): replaced by "as many items as the content has".
- Wikipedia's markup and citation-format tells: specific to Wikipedia. Our analogue is verified references and no
  leftover placeholders, TODOs or chat residue in deliverables.
- "Humanizer" paraphrasing services (QuillBot, Undetectable.ai and similar): they aim at fooling detectors and make
  academic prose worse.

## 12. Working rules
- Fable review, for big-picture writing only. Before handing over a first draft, a concept note or other
  big-picture writing (a new paper, a restructured draft), a Fable reviewer at max effort checks the quality of the
  writing, including AI-sounding prose. Claude applies the clear fixes and lists the judgment calls.
  - Revision rounds get no Fable review: applying comments, targeted edits, figure and layout fixes, small changes.
    Use the local checks instead (static checks, compile, page renders).
  - Skip the review whenever the user says so (user rules, 22 October 2026).
- Compile LaTeX locally (TinyTeX; VS Code LaTeX Workshop or `build/compile.py`) and look at the rendered pages before
  handing a paper or deck over: no errors, no undefined references, nothing running off a slide.
- Source hygiene. LaTeX files are shared with co-authors on Overleaf. Their comments say what a co-author needs
  (contents, where the numbers come from) and nothing about agents, coordinators, "the owner", who instructed whom,
  or internal digest paths. Strip workflow comments before delivery.
- Deliver new versions as new folders or dated files; keep the previous draft untouched.
- Report every specification that was tried; no cherry-picking. State plainly what is a decision for the user.
- When the user writes a section, provide placeholders, not prose.
