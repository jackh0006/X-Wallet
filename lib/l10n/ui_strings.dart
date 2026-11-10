// English is the only supported language.
const Map<String, Map<String, String>> uiTranslations = {};

String translateUi(String locale, String text) =>
    uiTranslations[locale]?[text] ?? text;
