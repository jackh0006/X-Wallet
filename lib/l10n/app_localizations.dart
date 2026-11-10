import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'X Wallet'**
  String get appTitle;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @receive.
  ///
  /// In en, this message translates to:
  /// **'Receive'**
  String get receive;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @inspect.
  ///
  /// In en, this message translates to:
  /// **'Inspect'**
  String get inspect;

  /// No description provided for @logs.
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get logs;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @wallet.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get wallet;

  /// No description provided for @balance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get balance;

  /// No description provided for @bnbBalance.
  ///
  /// In en, this message translates to:
  /// **'BNB Balance'**
  String get bnbBalance;

  /// No description provided for @tokenBalance.
  ///
  /// In en, this message translates to:
  /// **'{symbol} Balance'**
  String tokenBalance(Object symbol);

  /// No description provided for @address.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get address;

  /// No description provided for @copyAddress.
  ///
  /// In en, this message translates to:
  /// **'Copy address'**
  String get copyAddress;

  /// No description provided for @copySuccess.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get copySuccess;

  /// No description provided for @qrCode.
  ///
  /// In en, this message translates to:
  /// **'QR Code'**
  String get qrCode;

  /// No description provided for @receiveQR.
  ///
  /// In en, this message translates to:
  /// **'Receive QR'**
  String get receiveQR;

  /// No description provided for @sendAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount to send'**
  String get sendAmount;

  /// No description provided for @sendTo.
  ///
  /// In en, this message translates to:
  /// **'Send to'**
  String get sendTo;

  /// No description provided for @recipientAddress.
  ///
  /// In en, this message translates to:
  /// **'Recipient address'**
  String get recipientAddress;

  /// No description provided for @enterAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter amount'**
  String get enterAmount;

  /// No description provided for @max.
  ///
  /// In en, this message translates to:
  /// **'Max'**
  String get max;

  /// No description provided for @available.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get available;

  /// No description provided for @fee.
  ///
  /// In en, this message translates to:
  /// **'Fee'**
  String get fee;

  /// No description provided for @feeTier.
  ///
  /// In en, this message translates to:
  /// **'Fee tier'**
  String get feeTier;

  /// No description provided for @low.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get low;

  /// No description provided for @medium.
  ///
  /// In en, this message translates to:
  /// **'Medium (recommended)'**
  String get medium;

  /// No description provided for @high.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get high;

  /// No description provided for @custom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get custom;

  /// No description provided for @estimatedTime.
  ///
  /// In en, this message translates to:
  /// **'Estimated time'**
  String get estimatedTime;

  /// No description provided for @review.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get review;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @holdToConfirm.
  ///
  /// In en, this message translates to:
  /// **'Hold to confirm'**
  String get holdToConfirm;

  /// No description provided for @signing.
  ///
  /// In en, this message translates to:
  /// **'Signing...'**
  String get signing;

  /// No description provided for @broadcasting.
  ///
  /// In en, this message translates to:
  /// **'Broadcasting...'**
  String get broadcasting;

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// No description provided for @success.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get success;

  /// No description provided for @failed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get failed;

  /// No description provided for @transactionHash.
  ///
  /// In en, this message translates to:
  /// **'Transaction hash'**
  String get transactionHash;

  /// No description provided for @blockNumber.
  ///
  /// In en, this message translates to:
  /// **'Block number'**
  String get blockNumber;

  /// No description provided for @confirmations.
  ///
  /// In en, this message translates to:
  /// **'Confirmations'**
  String get confirmations;

  /// No description provided for @finalized.
  ///
  /// In en, this message translates to:
  /// **'Finalized'**
  String get finalized;

  /// No description provided for @sendAgain.
  ///
  /// In en, this message translates to:
  /// **'Send again'**
  String get sendAgain;

  /// No description provided for @addToContacts.
  ///
  /// In en, this message translates to:
  /// **'Add to contacts'**
  String get addToContacts;

  /// No description provided for @copyHash.
  ///
  /// In en, this message translates to:
  /// **'Copy hash'**
  String get copyHash;

  /// No description provided for @copyAll.
  ///
  /// In en, this message translates to:
  /// **'Copy all details'**
  String get copyAll;

  /// No description provided for @shareAsText.
  ///
  /// In en, this message translates to:
  /// **'Share as text'**
  String get shareAsText;

  /// No description provided for @exportJson.
  ///
  /// In en, this message translates to:
  /// **'Export JSON'**
  String get exportJson;

  /// No description provided for @exportPng.
  ///
  /// In en, this message translates to:
  /// **'Export PNG'**
  String get exportPng;

  /// No description provided for @openInExplorer.
  ///
  /// In en, this message translates to:
  /// **'Open in explorer'**
  String get openInExplorer;

  /// No description provided for @warningExplorer.
  ///
  /// In en, this message translates to:
  /// **'This opens an external website. The explorer will see your IP and the transaction you\'re interested in. Continue?'**
  String get warningExplorer;

  /// No description provided for @settingsNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get settingsNetwork;

  /// No description provided for @settingsNodes.
  ///
  /// In en, this message translates to:
  /// **'Nodes'**
  String get settingsNodes;

  /// No description provided for @settingsTokens.
  ///
  /// In en, this message translates to:
  /// **'Tokens'**
  String get settingsTokens;

  /// No description provided for @settingsSecurity.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get settingsSecurity;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get settingsPrivacy;

  /// No description provided for @settingsAutoLock.
  ///
  /// In en, this message translates to:
  /// **'Auto-lock'**
  String get settingsAutoLock;

  /// No description provided for @settingsErase.
  ///
  /// In en, this message translates to:
  /// **'Erase everything'**
  String get settingsErase;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themeAmoled.
  ///
  /// In en, this message translates to:
  /// **'AMOLED black'**
  String get themeAmoled;

  /// No description provided for @liteMode.
  ///
  /// In en, this message translates to:
  /// **'Lite mode (no animations)'**
  String get liteMode;

  /// No description provided for @reduceMotion.
  ///
  /// In en, this message translates to:
  /// **'Reduce motion (system)'**
  String get reduceMotion;

  /// No description provided for @torEnabled.
  ///
  /// In en, this message translates to:
  /// **'Tor enabled'**
  String get torEnabled;

  /// No description provided for @torHost.
  ///
  /// In en, this message translates to:
  /// **'Tor host'**
  String get torHost;

  /// No description provided for @torPort.
  ///
  /// In en, this message translates to:
  /// **'Tor port'**
  String get torPort;

  /// No description provided for @useCustomProxy.
  ///
  /// In en, this message translates to:
  /// **'Use custom proxy'**
  String get useCustomProxy;

  /// No description provided for @proxyHost.
  ///
  /// In en, this message translates to:
  /// **'Proxy host'**
  String get proxyHost;

  /// No description provided for @proxyPort.
  ///
  /// In en, this message translates to:
  /// **'Proxy port'**
  String get proxyPort;

  /// No description provided for @proxyUser.
  ///
  /// In en, this message translates to:
  /// **'Proxy username'**
  String get proxyUser;

  /// No description provided for @proxyPass.
  ///
  /// In en, this message translates to:
  /// **'Proxy password'**
  String get proxyPass;

  /// No description provided for @addNode.
  ///
  /// In en, this message translates to:
  /// **'Add node'**
  String get addNode;

  /// No description provided for @editNode.
  ///
  /// In en, this message translates to:
  /// **'Edit node'**
  String get editNode;

  /// No description provided for @nodeName.
  ///
  /// In en, this message translates to:
  /// **'Node name'**
  String get nodeName;

  /// No description provided for @nodeUrl.
  ///
  /// In en, this message translates to:
  /// **'Node URL'**
  String get nodeUrl;

  /// No description provided for @nodeNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get nodeNetwork;

  /// No description provided for @nodeTransport.
  ///
  /// In en, this message translates to:
  /// **'Transport'**
  String get nodeTransport;

  /// No description provided for @nodeAuth.
  ///
  /// In en, this message translates to:
  /// **'Authentication'**
  String get nodeAuth;

  /// No description provided for @authNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get authNone;

  /// No description provided for @authBearer.
  ///
  /// In en, this message translates to:
  /// **'Bearer token'**
  String get authBearer;

  /// No description provided for @authBasic.
  ///
  /// In en, this message translates to:
  /// **'Basic auth'**
  String get authBasic;

  /// No description provided for @bearerToken.
  ///
  /// In en, this message translates to:
  /// **'Bearer token'**
  String get bearerToken;

  /// No description provided for @basicUser.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get basicUser;

  /// No description provided for @basicPass.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get basicPass;

  /// No description provided for @customHeaders.
  ///
  /// In en, this message translates to:
  /// **'Custom headers'**
  String get customHeaders;

  /// No description provided for @pinnedSpki.
  ///
  /// In en, this message translates to:
  /// **'Pinned SPKI hashes (base64, one per line)'**
  String get pinnedSpki;

  /// No description provided for @useForReads.
  ///
  /// In en, this message translates to:
  /// **'Use for reads'**
  String get useForReads;

  /// No description provided for @useForBroadcast.
  ///
  /// In en, this message translates to:
  /// **'Use for broadcast'**
  String get useForBroadcast;

  /// No description provided for @selectionMode.
  ///
  /// In en, this message translates to:
  /// **'Selection mode'**
  String get selectionMode;

  /// No description provided for @selectionManual.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get selectionManual;

  /// No description provided for @selectionAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto-fastest'**
  String get selectionAuto;

  /// No description provided for @selectionRandom.
  ///
  /// In en, this message translates to:
  /// **'Round-robin / random'**
  String get selectionRandom;

  /// No description provided for @selectionQuorum.
  ///
  /// In en, this message translates to:
  /// **'Quorum'**
  String get selectionQuorum;

  /// No description provided for @testNode.
  ///
  /// In en, this message translates to:
  /// **'Test node'**
  String get testNode;

  /// No description provided for @nodeChecklist.
  ///
  /// In en, this message translates to:
  /// **'Node checklist'**
  String get nodeChecklist;

  /// No description provided for @tokenSources.
  ///
  /// In en, this message translates to:
  /// **'Token contract sources'**
  String get tokenSources;

  /// No description provided for @addToken.
  ///
  /// In en, this message translates to:
  /// **'Add token'**
  String get addToken;

  /// No description provided for @tokenAddress.
  ///
  /// In en, this message translates to:
  /// **'Token contract address'**
  String get tokenAddress;

  /// No description provided for @tokenSymbol.
  ///
  /// In en, this message translates to:
  /// **'Symbol'**
  String get tokenSymbol;

  /// No description provided for @tokenName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get tokenName;

  /// No description provided for @tokenDecimals.
  ///
  /// In en, this message translates to:
  /// **'Decimals'**
  String get tokenDecimals;

  /// No description provided for @hideToken.
  ///
  /// In en, this message translates to:
  /// **'Hide token'**
  String get hideToken;

  /// No description provided for @showToken.
  ///
  /// In en, this message translates to:
  /// **'Show token'**
  String get showToken;

  /// No description provided for @backupQuiz.
  ///
  /// In en, this message translates to:
  /// **'Backup quiz'**
  String get backupQuiz;

  /// No description provided for @verifyPhrase.
  ///
  /// In en, this message translates to:
  /// **'Verify recovery phrase'**
  String get verifyPhrase;

  /// No description provided for @watchOnly.
  ///
  /// In en, this message translates to:
  /// **'Watch-only'**
  String get watchOnly;

  /// No description provided for @importWatchOnly.
  ///
  /// In en, this message translates to:
  /// **'Import watch-only address'**
  String get importWatchOnly;

  /// No description provided for @enterAddress.
  ///
  /// In en, this message translates to:
  /// **'Enter address to watch'**
  String get enterAddress;

  /// No description provided for @coldMode.
  ///
  /// In en, this message translates to:
  /// **'Cold wallet mode'**
  String get coldMode;

  /// No description provided for @coldModeHot.
  ///
  /// In en, this message translates to:
  /// **'Normal (hot wallet)'**
  String get coldModeHot;

  /// No description provided for @coldModeCold.
  ///
  /// In en, this message translates to:
  /// **'Cold (offline signer)'**
  String get coldModeCold;

  /// No description provided for @coldModeOnline.
  ///
  /// In en, this message translates to:
  /// **'Online (watch-only companion)'**
  String get coldModeOnline;

  /// No description provided for @exportForOnline.
  ///
  /// In en, this message translates to:
  /// **'Export for online device'**
  String get exportForOnline;

  /// No description provided for @importPairing.
  ///
  /// In en, this message translates to:
  /// **'Import pairing data'**
  String get importPairing;

  /// No description provided for @coldHygiene.
  ///
  /// In en, this message translates to:
  /// **'Cold device hygiene'**
  String get coldHygiene;

  /// No description provided for @airplaneMode.
  ///
  /// In en, this message translates to:
  /// **'Airplane mode'**
  String get airplaneMode;

  /// No description provided for @wifi.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi'**
  String get wifi;

  /// No description provided for @mobileData.
  ///
  /// In en, this message translates to:
  /// **'Mobile data'**
  String get mobileData;

  /// No description provided for @bluetooth.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth'**
  String get bluetooth;

  /// No description provided for @nfc.
  ///
  /// In en, this message translates to:
  /// **'NFC'**
  String get nfc;

  /// No description provided for @networkInterface.
  ///
  /// In en, this message translates to:
  /// **'Network interface'**
  String get networkInterface;

  /// No description provided for @battery.
  ///
  /// In en, this message translates to:
  /// **'Battery'**
  String get battery;

  /// No description provided for @charging.
  ///
  /// In en, this message translates to:
  /// **'Charging'**
  String get charging;

  /// No description provided for @createWallet.
  ///
  /// In en, this message translates to:
  /// **'Create wallet'**
  String get createWallet;

  /// No description provided for @importWallet.
  ///
  /// In en, this message translates to:
  /// **'Import wallet'**
  String get importWallet;

  /// No description provided for @mnemonic.
  ///
  /// In en, this message translates to:
  /// **'Recovery phrase'**
  String get mnemonic;

  /// No description provided for @passphrase.
  ///
  /// In en, this message translates to:
  /// **'BIP-39 passphrase (optional)'**
  String get passphrase;

  /// No description provided for @passphraseHint.
  ///
  /// In en, this message translates to:
  /// **'Optional 25th word'**
  String get passphraseHint;

  /// No description provided for @confirmPhrase.
  ///
  /// In en, this message translates to:
  /// **'Confirm phrase'**
  String get confirmPhrase;

  /// No description provided for @enterWords.
  ///
  /// In en, this message translates to:
  /// **'Enter words {start}–{end}'**
  String enterWords(Object end, Object start);

  /// No description provided for @word.
  ///
  /// In en, this message translates to:
  /// **'Word'**
  String get word;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @import.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get import;

  /// No description provided for @unlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get unlock;

  /// No description provided for @lock.
  ///
  /// In en, this message translates to:
  /// **'Lock'**
  String get lock;

  /// No description provided for @pin.
  ///
  /// In en, this message translates to:
  /// **'PIN'**
  String get pin;

  /// No description provided for @biometric.
  ///
  /// In en, this message translates to:
  /// **'Biometric'**
  String get biometric;

  /// No description provided for @changePin.
  ///
  /// In en, this message translates to:
  /// **'Change PIN'**
  String get changePin;

  /// No description provided for @enablePin.
  ///
  /// In en, this message translates to:
  /// **'Enable PIN'**
  String get enablePin;

  /// No description provided for @disablePin.
  ///
  /// In en, this message translates to:
  /// **'Disable PIN'**
  String get disablePin;

  /// No description provided for @autoLockSeconds.
  ///
  /// In en, this message translates to:
  /// **'Auto-lock after'**
  String get autoLockSeconds;

  /// No description provided for @never.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get never;

  /// No description provided for @seconds.
  ///
  /// In en, this message translates to:
  /// **'seconds'**
  String get seconds;

  /// No description provided for @minutes.
  ///
  /// In en, this message translates to:
  /// **'minutes'**
  String get minutes;

  /// No description provided for @eraseAllData.
  ///
  /// In en, this message translates to:
  /// **'Erase all data'**
  String get eraseAllData;

  /// No description provided for @eraseWarning.
  ///
  /// In en, this message translates to:
  /// **'This will delete all wallets, keys, history, logs, and settings. Funds can only be recovered with your recovery phrase.'**
  String get eraseWarning;

  /// No description provided for @confirmErase.
  ///
  /// In en, this message translates to:
  /// **'Type \'ERASE\' to confirm'**
  String get confirmErase;

  /// No description provided for @holdToErase.
  ///
  /// In en, this message translates to:
  /// **'Hold to erase'**
  String get holdToErase;

  /// No description provided for @erasing.
  ///
  /// In en, this message translates to:
  /// **'Erasing...'**
  String get erasing;

  /// No description provided for @erased.
  ///
  /// In en, this message translates to:
  /// **'All data erased'**
  String get erased;

  /// No description provided for @logsSimple.
  ///
  /// In en, this message translates to:
  /// **'Simple'**
  String get logsSimple;

  /// No description provided for @logsExpert.
  ///
  /// In en, this message translates to:
  /// **'Expert'**
  String get logsExpert;

  /// No description provided for @logsFilter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get logsFilter;

  /// No description provided for @logsSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get logsSearch;

  /// No description provided for @logsExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get logsExport;

  /// No description provided for @logsClear.
  ///
  /// In en, this message translates to:
  /// **'Clear logs'**
  String get logsClear;

  /// No description provided for @logsWarning.
  ///
  /// In en, this message translates to:
  /// **'Exporting logs may reveal your activity. Continue?'**
  String get logsWarning;

  /// No description provided for @logLevelError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get logLevelError;

  /// No description provided for @logLevelWarn.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get logLevelWarn;

  /// No description provided for @logLevelInfo.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get logLevelInfo;

  /// No description provided for @logLevelDebug.
  ///
  /// In en, this message translates to:
  /// **'Debug'**
  String get logLevelDebug;

  /// No description provided for @logLevelTrace.
  ///
  /// In en, this message translates to:
  /// **'Trace'**
  String get logLevelTrace;

  /// No description provided for @logCategoryVault.
  ///
  /// In en, this message translates to:
  /// **'Vault'**
  String get logCategoryVault;

  /// No description provided for @logCategoryKeys.
  ///
  /// In en, this message translates to:
  /// **'Key operations'**
  String get logCategoryKeys;

  /// No description provided for @logCategoryNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get logCategoryNetwork;

  /// No description provided for @logCategoryTor.
  ///
  /// In en, this message translates to:
  /// **'Tor'**
  String get logCategoryTor;

  /// No description provided for @logCategoryFees.
  ///
  /// In en, this message translates to:
  /// **'Fees'**
  String get logCategoryFees;

  /// No description provided for @logCategoryTx.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get logCategoryTx;

  /// No description provided for @logCategoryTokens.
  ///
  /// In en, this message translates to:
  /// **'Tokens'**
  String get logCategoryTokens;

  /// No description provided for @logCategorySecurity.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get logCategorySecurity;

  /// No description provided for @journeyMap.
  ///
  /// In en, this message translates to:
  /// **'Journey Map'**
  String get journeyMap;

  /// No description provided for @journeyPhone.
  ///
  /// In en, this message translates to:
  /// **'My phone'**
  String get journeyPhone;

  /// No description provided for @journeyPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy layer'**
  String get journeyPrivacy;

  /// No description provided for @journeyNode.
  ///
  /// In en, this message translates to:
  /// **'Node'**
  String get journeyNode;

  /// No description provided for @journeyChain.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get journeyChain;

  /// No description provided for @journeyDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get journeyDone;

  /// No description provided for @stateWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get stateWaiting;

  /// No description provided for @stateWorking.
  ///
  /// In en, this message translates to:
  /// **'Working'**
  String get stateWorking;

  /// No description provided for @stateOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get stateOk;

  /// No description provided for @stateProblem.
  ///
  /// In en, this message translates to:
  /// **'Problem'**
  String get stateProblem;

  /// No description provided for @nodeCard.
  ///
  /// In en, this message translates to:
  /// **'Node'**
  String get nodeCard;

  /// No description provided for @nodeLatency.
  ///
  /// In en, this message translates to:
  /// **'Latency'**
  String get nodeLatency;

  /// No description provided for @nodeLatestBlock.
  ///
  /// In en, this message translates to:
  /// **'Latest block'**
  String get nodeLatestBlock;

  /// No description provided for @nodeRightChain.
  ///
  /// In en, this message translates to:
  /// **'Right chain'**
  String get nodeRightChain;

  /// No description provided for @nodeCompare.
  ///
  /// In en, this message translates to:
  /// **'Compare another'**
  String get nodeCompare;

  /// No description provided for @nodeSwitch.
  ///
  /// In en, this message translates to:
  /// **'Switch node'**
  String get nodeSwitch;

  /// No description provided for @receipt.
  ///
  /// In en, this message translates to:
  /// **'Receipt'**
  String get receipt;

  /// No description provided for @receiptStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get receiptStatus;

  /// No description provided for @receiptFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get receiptFrom;

  /// No description provided for @receiptTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get receiptTo;

  /// No description provided for @receiptAsset.
  ///
  /// In en, this message translates to:
  /// **'Asset'**
  String get receiptAsset;

  /// No description provided for @receiptAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get receiptAmount;

  /// No description provided for @receiptAmountRaw.
  ///
  /// In en, this message translates to:
  /// **'Raw amount'**
  String get receiptAmountRaw;

  /// No description provided for @receiptNonce.
  ///
  /// In en, this message translates to:
  /// **'Nonce'**
  String get receiptNonce;

  /// No description provided for @receiptGasLimit.
  ///
  /// In en, this message translates to:
  /// **'Gas limit'**
  String get receiptGasLimit;

  /// No description provided for @receiptGasUsed.
  ///
  /// In en, this message translates to:
  /// **'Gas used'**
  String get receiptGasUsed;

  /// No description provided for @receiptFee.
  ///
  /// In en, this message translates to:
  /// **'Fee'**
  String get receiptFee;

  /// No description provided for @receiptFeeTier.
  ///
  /// In en, this message translates to:
  /// **'Fee tier'**
  String get receiptFeeTier;

  /// No description provided for @receiptFeeReason.
  ///
  /// In en, this message translates to:
  /// **'Fee reason'**
  String get receiptFeeReason;

  /// No description provided for @receiptTxType.
  ///
  /// In en, this message translates to:
  /// **'Tx type'**
  String get receiptTxType;

  /// No description provided for @receiptInputData.
  ///
  /// In en, this message translates to:
  /// **'Input data'**
  String get receiptInputData;

  /// No description provided for @receiptEventLogs.
  ///
  /// In en, this message translates to:
  /// **'Event logs'**
  String get receiptEventLogs;

  /// No description provided for @receiptBlockHash.
  ///
  /// In en, this message translates to:
  /// **'Block hash'**
  String get receiptBlockHash;

  /// No description provided for @receiptTxIndex.
  ///
  /// In en, this message translates to:
  /// **'Transaction index'**
  String get receiptTxIndex;

  /// No description provided for @receiptBalances.
  ///
  /// In en, this message translates to:
  /// **'Balances before / after'**
  String get receiptBalances;

  /// No description provided for @receiptBefore.
  ///
  /// In en, this message translates to:
  /// **'Before'**
  String get receiptBefore;

  /// No description provided for @receiptAfter.
  ///
  /// In en, this message translates to:
  /// **'After'**
  String get receiptAfter;

  /// No description provided for @receiptVerified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get receiptVerified;

  /// No description provided for @receiptNodeUsed.
  ///
  /// In en, this message translates to:
  /// **'Node used'**
  String get receiptNodeUsed;

  /// No description provided for @receiptTransport.
  ///
  /// In en, this message translates to:
  /// **'Transport'**
  String get receiptTransport;

  /// No description provided for @securityNotice.
  ///
  /// In en, this message translates to:
  /// **'Security notice'**
  String get securityNotice;

  /// No description provided for @honestLimits.
  ///
  /// In en, this message translates to:
  /// **'Honest limits'**
  String get honestLimits;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @license.
  ///
  /// In en, this message translates to:
  /// **'License'**
  String get license;

  /// No description provided for @buildHash.
  ///
  /// In en, this message translates to:
  /// **'Build hash'**
  String get buildHash;

  /// No description provided for @sbom.
  ///
  /// In en, this message translates to:
  /// **'SBOM'**
  String get sbom;

  /// No description provided for @contact.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get contact;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get privacyPolicy;

  /// No description provided for @threatModel.
  ///
  /// In en, this message translates to:
  /// **'Threat model'**
  String get threatModel;

  /// No description provided for @architecture.
  ///
  /// In en, this message translates to:
  /// **'Architecture'**
  String get architecture;

  /// No description provided for @changelog.
  ///
  /// In en, this message translates to:
  /// **'Changelog'**
  String get changelog;

  /// No description provided for @contributing.
  ///
  /// In en, this message translates to:
  /// **'Contributing'**
  String get contributing;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @test.
  ///
  /// In en, this message translates to:
  /// **'Test'**
  String get test;

  /// No description provided for @verify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verify;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @paste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get paste;

  /// No description provided for @scan.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get scan;

  /// No description provided for @warning.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get warning;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @info.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get info;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @speedUp.
  ///
  /// In en, this message translates to:
  /// **'Speed up'**
  String get speedUp;

  /// No description provided for @cancelTx.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelTx;

  /// No description provided for @replaceTx.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get replaceTx;

  /// No description provided for @insufficientBnb.
  ///
  /// In en, this message translates to:
  /// **'Insufficient BNB for gas'**
  String get insufficientBnb;

  /// No description provided for @needBnb.
  ///
  /// In en, this message translates to:
  /// **'You need BNB to pay for gas. Receive some first.'**
  String get needBnb;

  /// No description provided for @addressPoisoning.
  ///
  /// In en, this message translates to:
  /// **'This address resembles a recent contact but differs. Verify carefully.'**
  String get addressPoisoning;

  /// No description provided for @selfContract.
  ///
  /// In en, this message translates to:
  /// **'Sending to the token\'s own contract address will burn tokens.'**
  String get selfContract;

  /// No description provided for @zeroAddress.
  ///
  /// In en, this message translates to:
  /// **'Sending to the zero address is not allowed.'**
  String get zeroAddress;

  /// No description provided for @newAddress.
  ///
  /// In en, this message translates to:
  /// **'This address has never been used before. Verify it carefully.'**
  String get newAddress;

  /// No description provided for @tokenSimulationFailed.
  ///
  /// In en, this message translates to:
  /// **'Simulation failed: {reason}'**
  String tokenSimulationFailed(Object reason);

  /// No description provided for @tokenUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown token'**
  String get tokenUnknown;

  /// No description provided for @unlimitedApproval.
  ///
  /// In en, this message translates to:
  /// **'Unlimited approval — token can spend all your balance'**
  String get unlimitedApproval;

  /// No description provided for @signUnknownData.
  ///
  /// In en, this message translates to:
  /// **'Sign unknown data (advanced)'**
  String get signUnknownData;

  /// No description provided for @enableSignUnknown.
  ///
  /// In en, this message translates to:
  /// **'Enable signing unknown calldata'**
  String get enableSignUnknown;

  /// No description provided for @blindSignWarning.
  ///
  /// In en, this message translates to:
  /// **'Blind signing is dangerous. Only enable if you understand the risks.'**
  String get blindSignWarning;

  /// No description provided for @disclosure.
  ///
  /// In en, this message translates to:
  /// **'Disclosure'**
  String get disclosure;

  /// No description provided for @nodeSees.
  ///
  /// In en, this message translates to:
  /// **'The node sees: your IP, the RPC method, and parameters. It can infer address linkages.'**
  String get nodeSees;

  /// No description provided for @appDoesNotSend.
  ///
  /// In en, this message translates to:
  /// **'The app does NOT send: device model, OS, app version, language, location, contacts, seed, keys, or passwords.'**
  String get appDoesNotSend;

  /// No description provided for @viewRawRequest.
  ///
  /// In en, this message translates to:
  /// **'View raw request'**
  String get viewRawRequest;

  /// No description provided for @copyLog.
  ///
  /// In en, this message translates to:
  /// **'Copy log'**
  String get copyLog;

  /// No description provided for @privacyScreen.
  ///
  /// In en, this message translates to:
  /// **'Network privacy'**
  String get privacyScreen;

  /// No description provided for @directMode.
  ///
  /// In en, this message translates to:
  /// **'Direct HTTPS'**
  String get directMode;

  /// No description provided for @torMode.
  ///
  /// In en, this message translates to:
  /// **'Tor (SOCKS5)'**
  String get torMode;

  /// No description provided for @bridgeMode.
  ///
  /// In en, this message translates to:
  /// **'Tor + bridge'**
  String get bridgeMode;

  /// No description provided for @proxyMode.
  ///
  /// In en, this message translates to:
  /// **'Custom proxy'**
  String get proxyMode;

  /// No description provided for @ispSees.
  ///
  /// In en, this message translates to:
  /// **'Your ISP sees:'**
  String get ispSees;

  /// No description provided for @ispNotSees.
  ///
  /// In en, this message translates to:
  /// **'Your ISP does NOT see:'**
  String get ispNotSees;

  /// No description provided for @nodeSeesPrivacy.
  ///
  /// In en, this message translates to:
  /// **'The RPC node sees:'**
  String get nodeSeesPrivacy;

  /// No description provided for @nodeNotSeesPrivacy.
  ///
  /// In en, this message translates to:
  /// **'The RPC node does NOT see:'**
  String get nodeNotSeesPrivacy;

  /// No description provided for @chainSees.
  ///
  /// In en, this message translates to:
  /// **'The blockchain sees:'**
  String get chainSees;

  /// No description provided for @chainNotSees.
  ///
  /// In en, this message translates to:
  /// **'The blockchain does NOT see:'**
  String get chainNotSees;

  /// No description provided for @trafficLightGreen.
  ///
  /// In en, this message translates to:
  /// **'Fully private'**
  String get trafficLightGreen;

  /// No description provided for @trafficLightYellow.
  ///
  /// In en, this message translates to:
  /// **'Partly private'**
  String get trafficLightYellow;

  /// No description provided for @trafficLightRed.
  ///
  /// In en, this message translates to:
  /// **'Blocked / failed'**
  String get trafficLightRed;

  /// No description provided for @bootstrap.
  ///
  /// In en, this message translates to:
  /// **'Bootstrap'**
  String get bootstrap;

  /// No description provided for @circuit.
  ///
  /// In en, this message translates to:
  /// **'Circuit'**
  String get circuit;

  /// No description provided for @hop.
  ///
  /// In en, this message translates to:
  /// **'Hop'**
  String get hop;

  /// No description provided for @bridgeType.
  ///
  /// In en, this message translates to:
  /// **'Bridge type'**
  String get bridgeType;

  /// No description provided for @killSwitch.
  ///
  /// In en, this message translates to:
  /// **'Kill switch'**
  String get killSwitch;

  /// No description provided for @whatCanTheySee.
  ///
  /// In en, this message translates to:
  /// **'What can they see?'**
  String get whatCanTheySee;

  /// No description provided for @yourIsp.
  ///
  /// In en, this message translates to:
  /// **'Your internet provider'**
  String get yourIsp;

  /// No description provided for @theNode.
  ///
  /// In en, this message translates to:
  /// **'The RPC node'**
  String get theNode;

  /// No description provided for @everyone.
  ///
  /// In en, this message translates to:
  /// **'Everyone on the blockchain'**
  String get everyone;

  /// No description provided for @sees.
  ///
  /// In en, this message translates to:
  /// **'Sees'**
  String get sees;

  /// No description provided for @cantSee.
  ///
  /// In en, this message translates to:
  /// **'Can\'t see'**
  String get cantSee;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageFarsi.
  ///
  /// In en, this message translates to:
  /// **'فارسی'**
  String get languageFarsi;

  /// No description provided for @languageArabic.
  ///
  /// In en, this message translates to:
  /// **'العربية'**
  String get languageArabic;

  /// No description provided for @languageChinese.
  ///
  /// In en, this message translates to:
  /// **'中文'**
  String get languageChinese;

  /// No description provided for @languageRussian.
  ///
  /// In en, this message translates to:
  /// **'Русский'**
  String get languageRussian;

  /// No description provided for @languageSpanish.
  ///
  /// In en, this message translates to:
  /// **'Español'**
  String get languageSpanish;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
