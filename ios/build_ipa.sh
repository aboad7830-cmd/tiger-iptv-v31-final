#!/usr/bin/env bash
# =============================================================================
#  TIGER IPTV — سكربت بناء IPA (macOS فقط)
# =============================================================================
#  الاستخدام:
#      chmod +x build_ipa.sh
#      ./build_ipa.sh                 # بناء موقّع للـ App Store
#      ./build_ipa.sh --unsigned      # بناء غير موقّع (للتثبيت عبر Sideloadly/AltStore)
#      ./build_ipa.sh --help
#
#  المخارج:
#      build/TIGER-IPTV.xcarchive
#      build/export/TIGER-IPTV.ipa
#
#  المتطلبات (الوضع الموقّع):
#      • macOS 14+ و Xcode 16+
#      • حساب Apple Developer + Team ID
#      • شهادة Apple Distribution + Provisioning Profile باسم التطبيق
#
#  المتطلبات (الوضع غير الموقّع):
#      • macOS 14+ و Xcode 16+ فقط. لا حاجة لأي حساب مطوّر.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

SCHEME="tiger-iptv"
PROJECT="tiger-iptv.xcodeproj"
WORKSPACE="tiger-iptv.xcworkspace"
ARCHIVE_PATH="build/TIGER-IPTV.xcarchive"
EXPORT_DIR="build/export"
FINAL_IPA="$EXPORT_DIR/TIGER-IPTV.ipa"

TEAM_ID="${TEAM_ID:-PM27C7JC3M}"
BUNDLE_ID="${BUNDLE_ID:-com.tigeriptv.app}"
METHOD="app-store-connect"
UNSIGNED=0
CLEAN=0
VERBOSE=0
EXPORT_PLIST="ExportOptions.plist"

usage() {
  cat <<'USAGE'
TIGER IPTV — بناء IPA

  ./build_ipa.sh [خيارات]

الخيارات:
  --unsigned              بناء IPA غير موقّع (بدون حساب Apple Developer)
  --method <value>        طريقة التصدير: app-store-connect | release-testing |
                          debugging | ad-hoc | development  (الافتراضي: app-store-connect)
  --team <TEAM_ID>        معرّف فريق Apple Developer (الافتراضي: PM27C7JC3M)
  --bundle <BUNDLE_ID>    معرّف الحزمة (الافتراضي: com.tigeriptv.app)
  --output <dir>          مجلد الإخراج (الافتراضي: build/export)
  --clean                 حذف مجلد build قبل البناء
  --verbose               طباعة أوامر xcodebuild كاملة
  -h, --help              هذه المساعدة

أمثلة:
  ./build_ipa.sh --unsigned
  ./build_ipa.sh --method release-testing
  ./build_ipa.sh --method ad-hoc --team ABCD123456
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --unsigned) UNSIGNED=1; shift ;;
    --method) METHOD="${2:?--method يحتاج قيمة}"; shift 2 ;;
    --team) TEAM_ID="${2:?--team يحتاج قيمة}"; shift 2 ;;
    --bundle) BUNDLE_ID="${2:?--bundle يحتاج قيمة}"; shift 2 ;;
    --output) EXPORT_DIR="${2:?--output يحتاج قيمة}"; FINAL_IPA="$EXPORT_DIR/TIGER-IPTV.ipa"; shift 2 ;;
    --clean) CLEAN=1; shift ;;
    --verbose) VERBOSE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "✖ خيار غير معروف: $1"; usage; exit 2 ;;
  esac
done

line() { printf '─%.0s' {1..62}; echo; }

line
echo " TIGER IPTV — Build & Export IPA"
if [[ $UNSIGNED -eq 1 ]]; then echo " الوضع: غير موقّع (Unsigned)"; else echo " الوضع: موقّع (Signed) — $METHOD"; fi
line

# 1) التحقق من البيئة ---------------------------------------------------------
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "✖ هذا السكربت يعمل على macOS فقط (يستخدم xcodebuild)."
  echo "  النظام الحالي: $(uname -s)"
  echo "  بدائل: GitHub Actions (macos-15) أو جهاز Mac أو خدمة Mac سحابية."
  exit 1
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "✖ لم يتم العثور على xcodebuild. ثبّت Xcode 16+ ثم:"
  echo "    sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
  exit 1
fi

# NOTE: never pipe `xcodebuild -version` into `head`. Xcode 16.4 on macOS 15
# raises an uncaught NSFileHandleOperationException ("Broken pipe", exit 134)
# when its stdout is closed early. Capture to a file instead.
XCODE_VERSION_OUT="$(xcodebuild -version 2>/dev/null || true)"
XCODE_VERSION="$(printf '%s\n' "$XCODE_VERSION_OUT" | awk 'NR==1{print $2}')"
XCODE_BUILD_LINE="$(printf '%s\n' "$XCODE_VERSION_OUT" | awk 'NR==2')"
if [[ -z "$XCODE_VERSION" ]]; then
  echo "✖ تعذّر قراءة نسخة Xcode."
  exit 1
fi
echo "✔ Xcode: $XCODE_VERSION ($XCODE_BUILD_LINE)"

XCODE_MAJOR="${XCODE_VERSION%%.*}"
if [[ "$XCODE_MAJOR" -lt 16 ]]; then
  echo "✖ يتطلب Xcode 16 أو أحدث. النسخة الحالية: $XCODE_VERSION"
  exit 1
fi

if [[ ! -d "$PROJECT" ]]; then
  if command -v xcodegen >/dev/null 2>&1; then
    echo "› توليد المشروع من project.yml عبر XcodeGen …"
    xcodegen generate
  else
    echo "✖ لا يوجد $PROJECT ولا أداة xcodegen."
    echo "  ثبّت XcodeGen:  brew install xcodegen"
    exit 1
  fi
fi

if [[ ! -d "Vendor/libmpv/Frameworks" ]]; then
  echo "✖ حزم libmpv غير موجودة في Vendor/libmpv/Frameworks"
  exit 1
fi

# 2) تنظيف اختياري ------------------------------------------------------------
if [[ $CLEAN -eq 1 ]]; then
  echo "› حذف مجلد build …"
  rm -rf build
fi
mkdir -p "$EXPORT_DIR"

# 3) تجهيز ExportOptions ------------------------------------------------------
if [[ $UNSIGNED -eq 0 ]]; then
  if [[ ! -f "$EXPORT_PLIST" ]]; then
    echo "✖ ملف $EXPORT_PLIST غير موجود."
    exit 1
  fi
  # تحديث Team ID / Bundle ID / method في نسخة مؤقتة دون تعديل الأصل.
  TMP_PLIST="build/ExportOptions.generated.plist"
  mkdir -p build
  cp "$EXPORT_PLIST" "$TMP_PLIST"
  /usr/libexec/PlistBuddy -c "Set :teamID $TEAM_ID" "$TMP_PLIST" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Add :teamID string $TEAM_ID" "$TMP_PLIST"
  /usr/libexec/PlistBuddy -c "Set :method $METHOD" "$TMP_PLIST" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Add :method string $METHOD" "$TMP_PLIST"
  /usr/libexec/PlistBuddy -c "Delete :provisioningProfiles" "$TMP_PLIST" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :provisioningProfiles dict" "$TMP_PLIST"
  /usr/libexec/PlistBuddy -c "Add :provisioningProfiles:$BUNDLE_ID string TIGER IPTV AppStore" "$TMP_PLIST"
  EXPORT_PLIST="$TMP_PLIST"
fi

# 4) اختيار المشروع/الـ workspace --------------------------------------------
if [[ -d "$WORKSPACE" ]]; then
  BUILD_TARGET=(-workspace "$WORKSPACE")
else
  BUILD_TARGET=(-project "$PROJECT")
fi

VERBOSE_FLAG=()
[[ $VERBOSE -eq 1 ]] && VERBOSE_FLAG=(-verbose)

# 5) جلب الحزم ---------------------------------------------------------------
echo "› تحديث حزم Swift Package Manager …"
if ! xcodebuild "${BUILD_TARGET[@]}" -scheme "$SCHEME" -resolvePackageDependencies ${VERBOSE_FLAG[@]+"${VERBOSE_FLAG[@]}"}; then
  echo "⚠ فشل جلب الحزم. جرّب: File → Packages → Reset Package Caches"
  echo "  أو احذف DerivedData ثم أعد المحاولة."
  exit 1
fi

# 6) الأرشفة ------------------------------------------------------------------
echo "› أرشفة المشروع (Release) …"
if [[ $UNSIGNED -eq 1 ]]; then
  xcodebuild \
    "${BUILD_TARGET[@]}" \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination "generic/platform=iOS" \
    -archivePath "$ARCHIVE_PATH" \
    -skipPackagePluginValidation \
    ${VERBOSE_FLAG[@]+"${VERBOSE_FLAG[@]}"} \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGN_ENTITLEMENTS="" \
    PROVISIONING_PROFILE_SPECIFIER="" \
    DEVELOPMENT_TEAM="" \
    archive
else
  xcodebuild \
    "${BUILD_TARGET[@]}" \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination "generic/platform=iOS" \
    -archivePath "$ARCHIVE_PATH" \
    -allowProvisioningUpdates \
    ${VERBOSE_FLAG[@]+"${VERBOSE_FLAG[@]}"} \
    CODE_SIGN_STYLE=Automatic \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
    archive
fi

if [[ ! -d "$ARCHIVE_PATH" ]]; then
  echo "✖ لم يتم إنشاء الأرشيف."
  exit 1
fi

# 7) تصدير IPA ----------------------------------------------------------------
if [[ $UNSIGNED -eq 1 ]]; then
  echo "› تجميع IPA غير موقّع …"
  APP_PATH="$ARCHIVE_PATH/Products/Applications/TIGER IPTV.app"
  if [[ ! -d "$APP_PATH" ]]; then
    APP_PATH="$(find "$ARCHIVE_PATH/Products/Applications" -maxdepth 1 -name '*.app' | head -n1)"
  fi
  if [[ -z "${APP_PATH:-}" || ! -d "$APP_PATH" ]]; then
    echo "✖ لم يتم العثور على التطبيق داخل الأرشيف."
    exit 1
  fi
  STAGE="build/unsigned"
  rm -rf "$STAGE"
  mkdir -p "$STAGE/Payload"
  cp -R "$APP_PATH" "$STAGE/Payload/"
  # مسار مطلق لأن zip يعمل من داخل مجلد المرحلة (STAGE)
  mkdir -p "$EXPORT_DIR"
  ABS_IPA="$(cd "$EXPORT_DIR" && pwd)/$(basename "$FINAL_IPA")"
  rm -f "$ABS_IPA"
  ( cd "$STAGE" && /usr/bin/zip -qry "$ABS_IPA" Payload )
  FINAL_IPA="$ABS_IPA"
  rm -rf "$STAGE"
else
  echo "› تصدير ملف IPA …"
  xcodebuild \
    -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_DIR" \
    -exportOptionsPlist "$EXPORT_PLIST" \
    -allowProvisioningUpdates \
    ${VERBOSE_FLAG[@]+"${VERBOSE_FLAG[@]}"}

  IPA_FILE="$(find "$EXPORT_DIR" -maxdepth 1 -name '*.ipa' | head -n1 || true)"
  if [[ -z "$IPA_FILE" ]]; then
    echo "✖ لم يتم إنتاج ملف IPA. راجع سجل الأخطاء أعلاه."
    exit 1
  fi
  if [[ "$IPA_FILE" != "$FINAL_IPA" ]]; then
    mv -f "$IPA_FILE" "$FINAL_IPA"
  fi
fi

# 8) التحقق النهائي -----------------------------------------------------------
if [[ ! -f "$FINAL_IPA" ]]; then
  echo "✖ ملف IPA غير موجود."
  exit 1
fi

if ! unzip -l "$FINAL_IPA" | grep -q 'Payload/.*\.app/'; then
  echo "✖ بنية IPA غير صحيحة (لا يوجد Payload/*.app)."
  exit 1
fi

line
echo "✔ تم البناء بنجاح!"
echo "  الأرشيف : $ARCHIVE_PATH"
echo "  ملف IPA : $FINAL_IPA"
echo "  الحجم   : $(du -h "$FINAL_IPA" | cut -f1)"
if [[ $UNSIGNED -eq 1 ]]; then
  echo "  ملاحظة  : هذا الملف غير موقّع. ثبّته عبر Sideloadly أو AltStore"
  echo "            (سيُعيدان توقيعه بحساب Apple ID الخاص بك)."
else
  echo "  الخطوة التالية: ارفع الملف عبر Transporter أو:"
  echo "    xcrun altool --upload-app -f \"$FINAL_IPA\" -t ios --apiKey <KEY> --apiIssuer <ISSUER>"
fi
line
