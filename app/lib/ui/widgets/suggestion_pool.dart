import 'dart:math';

/// Kinds of starter question, for their icon and colour.
enum SuggestionKind { hadith, fiqh, aqidah, tafsir, history, ethics }

/// Starter questions by interface language. Each new chat shows a different
/// few; the first four are the classic ones (kept first for screenshots).
const suggestionPool = <String, List<(String, SuggestionKind)>>{
  'ps': [
    ('د «إنما الأعمال بالنيات» حدیث چا روایت کړی دی؟', SuggestionKind.hadith),
    ('د فقهې کتابونه د عورت لمسولو او اودس په اړه څه وايي؟', SuggestionKind.fiqh),
    ('د جبرئیل په حدیث کې د احسان مانا څه ده؟', SuggestionKind.aqidah),
    ('علماوو د علم د طلب د فضیلت په اړه څه ویلي دي؟', SuggestionKind.ethics),
    ('د سفر لمونځ لنډول له کومه واټنه پیلېږي؟ د مذهبونو نظرونه', SuggestionKind.fiqh),
    ('د «الدين النصيحة» حدیث شرح څه ده؟', SuggestionKind.hadith),
    ('د آیت الکرسي فضیلت په کومو حدیثونو کې راغلی؟', SuggestionKind.tafsir),
    ('امام ابو حنیفه د کومو استاذانو شاګرد و؟', SuggestionKind.history),
    ('د روژې کفاره په کومو حالتونو کې واجبېږي؟', SuggestionKind.fiqh),
    ('د «لا ضرر ولا ضرار» قاعده څه مانا لري؟', SuggestionKind.fiqh),
    ('مفسرینو د «الصراط المستقيم» تفسیر څنګه کړی؟', SuggestionKind.tafsir),
    ('د غیبت حد او حکم څه دی؟', SuggestionKind.ethics),
    ('د ایمان زیاتوالی او کمښت: د اهل سنتو نظر', SuggestionKind.aqidah),
    ('د امام بخاري د صحیح د شرطونو په اړه علماوو څه ویلي؟', SuggestionKind.hadith),
    ('په زکات کې د سرو زرو نصاب څومره دی؟', SuggestionKind.fiqh),
    ('د بدر غزا کله او څنګه وشوه؟', SuggestionKind.history),
    ('د والدینو سره د نېکۍ په اړه کوم احادیث راغلي؟', SuggestionKind.ethics),
    ('د «إنا أنزلناه في ليلة القدر» تفسیر', SuggestionKind.tafsir),
  ],
  'ar': [
    ('من روى حديث «إنما الأعمال بالنيات»؟', SuggestionKind.hadith),
    ('ما حكم مس المرأة في نقض الوضوء عند المذاهب؟', SuggestionKind.fiqh),
    ('ما معنى الإحسان في حديث جبريل؟', SuggestionKind.aqidah),
    ('ماذا قال العلماء في فضل طلب العلم؟', SuggestionKind.ethics),
    ('ما مسافة القصر عند المذاهب الأربعة؟', SuggestionKind.fiqh),
    ('ما شرح حديث «الدين النصيحة»؟', SuggestionKind.hadith),
    ('ما ورد في فضل آية الكرسي؟', SuggestionKind.tafsir),
    ('من شيوخ الإمام أبي حنيفة؟', SuggestionKind.history),
    ('متى تجب كفارة الصوم؟', SuggestionKind.fiqh),
    ('ما معنى قاعدة «لا ضرر ولا ضرار»؟', SuggestionKind.fiqh),
    ('كيف فسّر المفسرون «الصراط المستقيم»؟', SuggestionKind.tafsir),
    ('ما حد الغيبة وما حكمها؟', SuggestionKind.ethics),
    ('هل يزيد الإيمان وينقص عند أهل السنة؟', SuggestionKind.aqidah),
    ('ما شروط البخاري في صحيحه كما ذكرها العلماء؟', SuggestionKind.hadith),
    ('كم نصاب الذهب في الزكاة؟', SuggestionKind.fiqh),
    ('متى كانت غزوة بدر وما خبرها؟', SuggestionKind.history),
    ('ما ورد في بر الوالدين من الأحاديث؟', SuggestionKind.ethics),
    ('ما تفسير سورة القدر؟', SuggestionKind.tafsir),
  ],
  'fa': [
    ('حدیث «إنما الأعمال بالنيات» را چه کسی روایت کرده است؟', SuggestionKind.hadith),
    ('کتاب‌های فقه درباره لمس زن و وضو چه می‌گویند؟', SuggestionKind.fiqh),
    ('معنای احسان در حدیث جبرئیل چیست؟', SuggestionKind.aqidah),
    ('علما درباره فضیلت طلب علم چه گفته‌اند؟', SuggestionKind.ethics),
    ('مسافت قصر نماز در مذاهب چقدر است؟', SuggestionKind.fiqh),
    ('شرح حدیث «الدين النصيحة» چیست؟', SuggestionKind.hadith),
    ('درباره فضیلت آیة الکرسی چه روایت‌هایی آمده است؟', SuggestionKind.tafsir),
    ('استادان امام ابوحنیفه چه کسانی بودند؟', SuggestionKind.history),
    ('کفاره روزه در چه حالتی واجب می‌شود؟', SuggestionKind.fiqh),
    ('قاعده «لا ضرر ولا ضرار» یعنی چه؟', SuggestionKind.fiqh),
    ('مفسران «الصراط المستقيم» را چگونه تفسیر کرده‌اند؟', SuggestionKind.tafsir),
    ('حد و حکم غیبت چیست؟', SuggestionKind.ethics),
    ('افزایش و کاهش ایمان از نگاه اهل سنت', SuggestionKind.aqidah),
    ('شروط بخاری در صحیحش از نگاه علما چیست؟', SuggestionKind.hadith),
    ('نصاب طلا در زکات چقدر است؟', SuggestionKind.fiqh),
    ('غزوه بدر کی و چگونه رخ داد؟', SuggestionKind.history),
    ('درباره نیکی به پدر و مادر چه احادیثی آمده است؟', SuggestionKind.ethics),
    ('تفسیر سوره قدر', SuggestionKind.tafsir),
  ],
  'en': [
    ('Who narrated the hadith «Actions are only by intentions»?', SuggestionKind.hadith),
    ('What do the fiqh books say about touching a woman and wudu?', SuggestionKind.fiqh),
    ('What does ihsan mean in the hadith of Jibril?', SuggestionKind.aqidah),
    ('What did the scholars say about the virtue of seeking knowledge?', SuggestionKind.ethics),
    ('From what distance may a traveller shorten prayer, by madhhab?', SuggestionKind.fiqh),
    ('How is the hadith «The religion is sincere counsel» explained?', SuggestionKind.hadith),
    ('What is reported about the virtue of Ayat al-Kursi?', SuggestionKind.tafsir),
    ('Who were the teachers of Imam Abu Hanifa?', SuggestionKind.history),
    ('When is the expiation (kaffara) for fasting due?', SuggestionKind.fiqh),
    ('What does the maxim «No harm and no harming» mean?', SuggestionKind.fiqh),
    ('How did the exegetes explain «the straight path»?', SuggestionKind.tafsir),
    ('What is backbiting (ghiba) and its ruling?', SuggestionKind.ethics),
    ('Does faith increase and decrease, according to Ahl al-Sunna?', SuggestionKind.aqidah),
    ('What conditions did al-Bukhari set for his Sahih?', SuggestionKind.hadith),
    ('What is the zakat threshold (nisab) for gold?', SuggestionKind.fiqh),
    ('When and how did the Battle of Badr take place?', SuggestionKind.history),
    ('Which hadiths speak of kindness to parents?', SuggestionKind.ethics),
    ('The tafsir of Surat al-Qadr', SuggestionKind.tafsir),
  ],
};

/// [count] starter questions for [language]: a fresh random mix, one of each
/// kind where possible, or the first ones when [fixed].
List<(String, SuggestionKind)> pickSuggestions(String language, {int count = 4, bool fixed = false, Random? random}) {
  final pool = suggestionPool[language] ?? suggestionPool['en']!;
  if (fixed) return pool.take(count).toList();
  final shuffled = [...pool]..shuffle(random ?? Random());
  final out = <(String, SuggestionKind)>[];
  final kinds = <SuggestionKind>{};
  for (final s in shuffled) {
    if (out.length == count) break;
    if (kinds.add(s.$2)) out.add(s);
  }
  for (final s in shuffled) {
    if (out.length == count) break;
    if (!out.contains(s)) out.add(s);
  }
  return out;
}
