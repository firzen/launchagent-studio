const translations = {
  en: {
    navFeatures: "Features",
    navGuide: "Get started",
    eyebrow: "Native macOS utility · macOS 13+",
    heroTitle: "A visual task scheduler for your Mac.",
    heroLead: "Create and manage launchd tasks without hand-editing plist files. A friendly, macOS-native alternative to crontab for everyday user-level automation.",
    download: "Download for macOS",
    releaseNotes: "View release notes",
    downloadMeta: "Version 1.5.0 · Universal binary for Apple Silicon and Intel",
    enabledFirst: "Enabled tasks first",
    dailySchedule: "Daily schedules",
    native: "Native",
    nativeDetail: "SwiftUI macOS app",
    private: "Local",
    privateDetail: "No account or cloud service",
    safe: "Recoverable",
    safeDetail: "Deleted tasks go to Trash",
    bilingual: "Bilingual",
    bilingualDetail: "English and Simplified Chinese",
    whyKicker: "WHY LAUNCHAGENT STUDIO",
    whyTitle: "Automation that feels like a Mac app.",
    whyLead: "launchd is powerful, but its configuration files are not designed for quick, everyday use. LaunchAgent Studio adds a clear interface without hiding what macOS is doing.",
    featureCreateTitle: "Create schedules visually",
    featureCreateText: "Open an app, run a Shell script, or execute a command daily, at login, or on a fixed interval.",
    featureManageTitle: "Manage the full lifecycle",
    featureManageText: "Enable, disable, run immediately, inspect configuration, open logs, and remove user tasks from one place.",
    featureNamesTitle: "Understand every task",
    featureNamesText: "Friendly names and readable schedules make background services easier to identify than raw plist labels.",
    createKicker: "CREATE A TASK",
    createTitle: "From an idea to a schedule in one window.",
    createLead: "Choose what should run, decide when it should run, and optionally enable it immediately. The configuration is saved as a standard LaunchAgent in your user Library.",
    createPoint1: "Applications, Shell scripts, and commands",
    createPoint2: "Daily, login, and interval triggers",
    createPoint3: "Standard plist files remain visible and editable",
    guideKicker: "GET STARTED",
    guideTitle: "Running in three simple steps.",
    step1Title: "Download",
    step1Text: "Get the universal ZIP from the latest GitHub Release and extract it.",
    step2Title: "Move to Applications",
    step2Text: "Drag LaunchAgent Studio into your Applications folder.",
    step3Title: "Open and manage",
    step3Text: "Control-click the app and choose Open on the first launch, then create or manage your tasks.",
    noticeTitle: "A note about the first launch",
    noticeText: "The current public build is ad-hoc signed and not notarized. If macOS blocks it, Control-click the app and choose Open. LaunchAgent Studio only manages tasks in ~/Library/LaunchAgents and does not request administrator privileges.",
    faqKicker: "COMMON QUESTIONS",
    faqTitle: "A native home for recurring tasks.",
    faqCronQuestion: "Can it replace crontab?",
    faqCronAnswer: "For many user-level scheduled jobs, yes. LaunchAgent Studio uses macOS launchd rather than cron, so the scheduling model is different, but daily, login, and fixed-interval automation is covered.",
    faqServerQuestion: "Does it need a server or account?",
    faqServerAnswer: "No. The app works locally on your Mac. This product page and its downloads are hosted by GitHub.",
    faqAdminQuestion: "Does it manage system services?",
    faqAdminAnswer: "No. It is intentionally limited to user LaunchAgents and does not manage system LaunchDaemons or request administrator access.",
    ctaTitle: "Put recurring Mac tasks in one clear place.",
    ctaText: "Download LaunchAgent Studio and replace plist editing with a focused native interface.",
    viewSource: "View on GitHub",
    footerText: "A native macOS utility by firzen.",
    allReleases: "All releases"
  },
  zh: {
    navFeatures: "功能",
    navGuide: "开始使用",
    eyebrow: "macOS 原生工具 · 支持 macOS 13+",
    heroTitle: "Mac 上的可视化定时任务管理器。",
    heroLead: "无需手动编辑 plist，即可创建和管理 launchd 任务。它是适合日常用户级自动化的 macOS 原生 crontab 替代方案。",
    download: "下载 macOS 版",
    releaseNotes: "查看发布说明",
    downloadMeta: "版本 1.5.0 · 同时支持 Apple 芯片与 Intel",
    enabledFirst: "启用任务优先显示",
    dailySchedule: "每天定时运行",
    native: "原生",
    nativeDetail: "SwiftUI macOS 应用",
    private: "本地运行",
    privateDetail: "无需账户或云服务",
    safe: "可恢复",
    safeDetail: "删除的任务移到废纸篓",
    bilingual: "双语",
    bilingualDetail: "English 与简体中文",
    whyKicker: "为什么选择 LAUNCHAGENT STUDIO",
    whyTitle: "让自动化任务像 Mac 应用一样清晰。",
    whyLead: "launchd 功能强大，但配置文件并不适合日常快速操作。LaunchAgent Studio 提供清晰界面，同时保留 macOS 原生任务机制。",
    featureCreateTitle: "可视化创建定时任务",
    featureCreateText: "按每天固定时间、登录时或固定间隔打开应用、运行 Shell 脚本或执行命令。",
    featureManageTitle: "完整管理任务状态",
    featureManageText: "在同一界面启用、禁用、立即运行、查看配置、打开日志和删除用户任务。",
    featureNamesTitle: "看懂每一个任务",
    featureNamesText: "友好名称和可读的时间说明，比原始 plist 标识更容易识别后台服务。",
    createKicker: "新建任务",
    createTitle: "在一个窗口里完成任务与时间设置。",
    createLead: "选择运行内容与触发时间，并决定创建后是否立即启用。配置会作为标准 LaunchAgent 保存在用户资源库中。",
    createPoint1: "支持应用、Shell 脚本和命令",
    createPoint2: "支持每天、登录和固定间隔触发",
    createPoint3: "标准 plist 文件仍然可见、可编辑",
    guideKicker: "开始使用",
    guideTitle: "简单三步即可运行。",
    step1Title: "下载安装包",
    step1Text: "从最新 GitHub Release 下载通用 ZIP 安装包并解压。",
    step2Title: "移到应用程序",
    step2Text: "将 LaunchAgent Studio 拖入「应用程序」文件夹。",
    step3Title: "打开并管理",
    step3Text: "首次启动时右键应用并选择「打开」，随后即可创建或管理任务。",
    noticeTitle: "关于首次启动",
    noticeText: "当前公开版本使用临时签名，尚未经过 Apple 公证。如果 macOS 阻止启动，请右键应用并选择「打开」。LaunchAgent Studio 仅管理 ~/Library/LaunchAgents 中的任务，不需要管理员权限。",
    faqKicker: "常见问题",
    faqTitle: "给循环任务一个原生的管理界面。",
    faqCronQuestion: "可以替代 crontab 吗？",
    faqCronAnswer: "对于多数用户级定时任务，可以。LaunchAgent Studio 使用 macOS 的 launchd 而不是 cron，两者调度模型不同，但已经覆盖每天、登录时和固定间隔自动化。",
    faqServerQuestion: "需要服务器或账户吗？",
    faqServerAnswer: "不需要。应用完全在 Mac 本地运行，产品网页和安装包由 GitHub 托管。",
    faqAdminQuestion: "可以管理系统服务吗？",
    faqAdminAnswer: "不可以。应用只管理用户 LaunchAgent，不管理系统 LaunchDaemon，也不会请求管理员权限。",
    ctaTitle: "把 Mac 上的循环任务放在一个清晰界面里。",
    ctaText: "下载 LaunchAgent Studio，用专注的原生界面替代 plist 手动编辑。",
    viewSource: "在 GitHub 查看",
    footerText: "firzen 制作的 macOS 原生工具。",
    allReleases: "全部版本"
  }
};

const languageButtons = document.querySelectorAll("[data-language]");
const translatedElements = document.querySelectorAll("[data-i18n]");

function applyLanguage(language) {
  const selected = translations[language] ? language : "en";
  document.documentElement.lang = selected === "zh" ? "zh-CN" : "en";

  translatedElements.forEach((element) => {
    const key = element.dataset.i18n;
    const value = translations[selected][key];
    if (value) element.textContent = value;
  });

  languageButtons.forEach((button) => {
    button.setAttribute("aria-pressed", String(button.dataset.language === selected));
  });

  localStorage.setItem("launchagent-studio-language", selected);
}

languageButtons.forEach((button) => {
  button.addEventListener("click", () => applyLanguage(button.dataset.language));
});

const storedLanguage = localStorage.getItem("launchagent-studio-language");
const systemLanguage = navigator.language.toLowerCase().startsWith("zh") ? "zh" : "en";
applyLanguage(storedLanguage || systemLanguage);
