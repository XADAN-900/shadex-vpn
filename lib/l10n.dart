import 'package:flutter/widgets.dart';

/// Basit çeviri sistemi. Sıra: tr, en, fr, es, pt, ru, ar.
class L10n {
  static const codes = ['tr', 'en', 'fr', 'es', 'pt', 'ru', 'ar'];
  static const names = {
    'tr': 'Türkçe',
    'en': 'English',
    'fr': 'Français',
    'es': 'Español',
    'pt': 'Português',
    'ru': 'Русский',
    'ar': 'العربية',
  };

  /// Telefonun dili desteklenmiyorsa kullanılacak dil.
  static const fallbackCode = 'en';

  /// Şu an kullanılan dil. Telefonun diline göre otomatik belirlenir.
  static String code = fallbackCode;

  static Locale get locale => Locale(code);

  /// Telefonun dilinden uygulama dilini seçer.
  static Locale resolve(Locale? device) => resolveList([if (device != null) device]);

  /// Telefonun dil listesinden ilk desteklenen dili seçer (MaterialApp çağırır).
  static Locale resolveList(List<Locale>? device) {
    code = fallbackCode;
    for (final l in device ?? const <Locale>[]) {
      if (codes.contains(l.languageCode)) {
        code = l.languageCode;
        break;
      }
    }
    return Locale(code);
  }

  /// Dil değişince yeniden çizilmek için build içinde çağrılır.
  static void watch(BuildContext context) => Localizations.localeOf(context);

  static String t(String key, [Map<String, Object>? args]) {
    final row = _strings[key];
    if (row == null) return key;
    var s = row[codes.indexOf(code)];
    if (args != null) {
      args.forEach((k, v) => s = s.replaceAll('{$k}', '$v'));
    }
    return s;
  }
}

String tr(String key, [Map<String, Object>? args]) => L10n.t(key, args);

const Map<String, List<String>> _strings = {
  // ---------------------------------------------------------------- aşamalar
  'st_prepare': ["Hazırlanıyor", "Preparing", "Préparation", "Preparando", "Preparando", "Подготовка", "جارٍ التحضير"],
  'st_resolve': ["Sunucu bulunuyor", "Finding server", "Recherche du serveur", "Buscando servidor", "Procurando servidor", "Поиск сервера", "جارٍ البحث عن الخادم"],
  'st_server': ["Sunucuya bağlanılıyor", "Connecting to server", "Connexion au serveur", "Conectando al servidor", "Conectando ao servidor", "Подключение к серверу", "جارٍ الاتصال بالخادم"],
  'st_wait': ["Sunucu bekleniyor", "Waiting for server", "En attente du serveur", "Esperando al servidor", "Aguardando servidor", "Ожидание сервера", "بانتظار الخادم"],
  'st_auth': ["Güvenli oturum açılıyor", "Securing session", "Sécurisation de la session", "Asegurando la sesión", "Protegendo a sessão", "Защита сеанса", "جارٍ تأمين الجلسة"],
  'st_config': ["Ayarlar alınıyor", "Getting settings", "Récupération des paramètres", "Obteniendo ajustes", "Obtendo configurações", "Получение настроек", "جارٍ جلب الإعدادات"],
  'st_ip': ["IP adresi alınıyor", "Getting IP address", "Obtention de l'adresse IP", "Obteniendo dirección IP", "Obtendo endereço IP", "Получение IP-адреса", "جارٍ الحصول على عنوان IP"],
  'st_routes': ["Tünel hazırlanıyor", "Building tunnel", "Création du tunnel", "Creando el túnel", "Criando o túnel", "Создание туннеля", "جارٍ إنشاء النفق"],
  'st_connecting': ["Bağlanıyor", "Connecting", "Connexion", "Conectando", "Conectando", "Подключение", "جارٍ الاتصال"],
  'st_connected': ["Korumalı • Bağlı", "Protected • Connected", "Protégé • Connecté", "Protegido • Conectado", "Protegido • Conectado", "Защищено • Подключено", "محمي • متصل"],
  'st_reconnect': ["Yeniden bağlanıyor", "Reconnecting", "Reconnexion", "Reconectando", "Reconectando", "Переподключение", "جارٍ إعادة الاتصال"],
  'st_no_network': ["İnternet bekleniyor", "Waiting for internet", "En attente d'Internet", "Esperando internet", "Aguardando internet", "Ожидание интернета", "بانتظار الإنترنت"],
  'st_paused': ["Duraklatıldı", "Paused", "En pause", "En pausa", "Pausado", "Приостановлено", "متوقف مؤقتًا"],
  'st_auth_pending': ["Doğrulama bekleniyor", "Waiting for verification", "Vérification en attente", "Esperando verificación", "Aguardando verificação", "Ожидание проверки", "بانتظار التحقق"],
  'st_disconnecting': ["Bağlantı kesiliyor", "Disconnecting", "Déconnexion", "Desconectando", "Desconectando", "Отключение", "جارٍ قطع الاتصال"],
  'st_unprotected': ["Korumasız", "Not protected", "Non protégé", "Sin protección", "Desprotegido", "Не защищено", "غير محمي"],
  'st_denied': ["VPN izni verilmedi", "VPN permission denied", "Autorisation VPN refusée", "Permiso de VPN denegado", "Permissão de VPN negada", "Доступ к VPN запрещён", "تم رفض إذن VPN"],
  'st_auth_failed': ["Sunucu bağlantıyı reddetti", "Server rejected the connection", "Le serveur a refusé la connexion", "El servidor rechazó la conexión", "O servidor recusou a conexão", "Сервер отклонил подключение", "رفض الخادم الاتصال"],
  'st_error': ["Bağlantı hatası", "Connection error", "Erreur de connexion", "Error de conexión", "Erro de conexão", "Ошибка подключения", "خطأ في الاتصال"],
  'switching': ["Sunucu değiştiriliyor", "Switching server", "Changement de serveur", "Cambiando de servidor", "Trocando de servidor", "Смена сервера", "جارٍ تبديل الخادم"],
  'speed_testing': ["Hız ölçülüyor…", "Testing speed…", "Test de vitesse…", "Midiendo velocidad…", "Testando velocidade…", "Проверка скорости…", "جارٍ اختبار السرعة…"],
  'speed_now': ["Hız: {v} Mbps", "Speed: {v} Mbps", "Débit : {v} Mbps", "Velocidad: {v} Mbps", "Velocidade: {v} Mbps", "Скорость: {v} Мбит/с", "السرعة: {v} Mbps"],
  'slow_switching': ["Sunucu yavaş, daha hızlısına geçiliyor", "Server is slow, switching to a faster one", "Serveur lent, passage à un plus rapide", "Servidor lento, cambiando a uno más rápido", "Servidor lento, trocando por um mais rápido", "Сервер медленный, переключаемся на более быстрый", "الخادم بطيء، جارٍ التبديل إلى خادم أسرع"],
  'finding_server': ["Uygun sunucu kontrol ediliyor", "Checking available servers", "Vérification des serveurs disponibles", "Comprobando servidores disponibles", "Verificando servidores disponíveis", "Проверка доступных серверов", "جارٍ التحقق من الخوادم المتاحة"],
  'country_failed': ["{c} sunucularına şu an bağlanılamıyor. Başka bir ülke seç.", "Can't connect to {c} servers right now. Pick another country.", "Impossible de joindre les serveurs {c} pour le moment. Choisissez un autre pays.", "No se puede conectar a los servidores de {c} ahora. Elige otro país.", "Não é possível conectar aos servidores de {c} agora. Escolha outro país.", "Сейчас не удаётся подключиться к серверам {c}. Выберите другую страну.", "تعذّر الاتصال بخوادم {c} حاليًا. اختر دولة أخرى."],
  'n_ready': ["{n} sunucu hazır", "{n} servers ready", "{n} serveurs prêts", "{n} servidores listos", "{n} servidores prontos", "Готово серверов: {n}", "{n} خادم جاهز"],
  'checking_list': ["Uygun sunucular kontrol ediliyor…", "Checking which servers are available…", "Vérification des serveurs disponibles…", "Comprobando qué servidores están disponibles…", "Verificando quais servidores estão disponíveis…", "Проверяем, какие серверы доступны…", "جارٍ التحقق من الخوادم المتاحة…"],
  'trying_next': ["Daha hızlı sunucu deneniyor ({n}/{max})", "Trying a faster server ({n}/{max})", "Essai d'un serveur plus rapide ({n}/{max})", "Probando un servidor más rápido ({n}/{max})", "Tentando um servidor mais rápido ({n}/{max})", "Пробуем более быстрый сервер ({n}/{max})", "تجربة خادم أسرع ({n}/{max})"],

  // --------------------------------------------------------------- ana ekran
  'btn_connect': ["BAĞLAN", "CONNECT", "CONNEXION", "CONECTAR", "CONECTAR", "ПОДКЛЮЧИТЬ", "اتصال"],
  'btn_disconnect': ["BAĞLANTIYI KES", "DISCONNECT", "DÉCONNECTER", "DESCONECTAR", "DESCONECTAR", "ОТКЛЮЧИТЬ", "قطع الاتصال"],
  'btn_cancel': ["İPTAL", "CANCEL", "ANNULER", "CANCELAR", "CANCELAR", "ОТМЕНА", "إلغاء"],
  'hint_tap': ["Korunmak için düğmeye dokun", "Tap the button to get protected", "Touchez le bouton pour être protégé", "Toca el botón para protegerte", "Toque no botão para se proteger", "Нажмите кнопку, чтобы защититься", "اضغط الزر لتكون محميًا"],
  'hint_building': ["Güvenli tünel kuruluyor…", "Building a secure tunnel…", "Création d'un tunnel sécurisé…", "Creando un túnel seguro…", "Criando um túnel seguro…", "Создаём защищённый туннель…", "جارٍ إنشاء نفق آمن…"],
  'ip_real': ["Gerçek IP adresin", "Your real IP", "Votre IP réelle", "Tu IP real", "Seu IP real", "Ваш реальный IP", "عنوان IP الحقيقي"],
  'ip_visible': ["Görünen IP adresin", "Your visible IP", "Votre IP visible", "Tu IP visible", "Seu IP visível", "Ваш видимый IP", "عنوان IP الظاهر"],
  'ip_checking': ["Kontrol ediliyor…", "Checking…", "Vérification…", "Comprobando…", "Verificando…", "Проверка…", "جارٍ التحقق…"],
  'ip_unknown': ["Bilinmiyor", "Unknown", "Inconnue", "Desconocida", "Desconhecido", "Неизвестно", "غير معروف"],
  'ip_refresh': ["IP adresini yenile", "Refresh IP", "Actualiser l'IP", "Actualizar IP", "Atualizar IP", "Обновить IP", "تحديث IP"],
  'download': ["İndirme", "Download", "Réception", "Descarga", "Download", "Загрузка", "تنزيل"],
  'upload': ["Yükleme", "Upload", "Envoi", "Subida", "Upload", "Отдача", "رفع"],
  'servers_preparing': ["Sunucular hazırlanıyor…", "Preparing servers…", "Préparation des serveurs…", "Preparando servidores…", "Preparando servidores…", "Подготовка серверов…", "جارٍ تجهيز الخوادم…"],
  'one_moment': ["Bir saniye", "One moment", "Un instant", "Un momento", "Um momento", "Секунду", "لحظة واحدة"],
  'servers_unreachable': ["Sunuculara ulaşılamadı", "Couldn't reach servers", "Serveurs inaccessibles", "No se pudo acceder a los servidores", "Não foi possível acessar os servidores", "Серверы недоступны", "تعذّر الوصول إلى الخوادم"],
  'check_internet_retry': ["İnternetini kontrol et • tekrar denemek için dokun", "Check your internet • tap to retry", "Vérifiez Internet • touchez pour réessayer", "Revisa tu internet • toca para reintentar", "Verifique a internet • toque para tentar de novo", "Проверьте интернет • нажмите для повтора", "تحقق من الإنترنت • اضغط لإعادة المحاولة"],
  'fastest_server': ["En hızlı sunucu", "Fastest server", "Serveur le plus rapide", "Servidor más rápido", "Servidor mais rápido", "Самый быстрый сервер", "أسرع خادم"],
  'disconnect_to_change': ["Değiştirmek için bağlantıyı kes", "Disconnect to change", "Déconnectez pour changer", "Desconecta para cambiar", "Desconecte para trocar", "Отключитесь, чтобы сменить", "اقطع الاتصال للتغيير"],
  'measuring': ["Hızlar ölçülüyor…", "Measuring speeds…", "Mesure des vitesses…", "Midiendo velocidades…", "Medindo velocidades…", "Измеряем скорость…", "جارٍ قياس السرعات…"],
  'tap_to_change': ["dokun ve değiştir", "tap to change", "touchez pour changer", "toca para cambiar", "toque para trocar", "нажмите, чтобы сменить", "اضغط للتغيير"],
  'auto_selected': ["otomatik seçildi", "picked automatically", "choisi automatiquement", "elegido automáticamente", "escolhido automaticamente", "выбран автоматически", "تم اختياره تلقائيًا"],
  'snack_loading': ["Sunucular yükleniyor, bir saniye…", "Loading servers, one moment…", "Chargement des serveurs, un instant…", "Cargando servidores, un momento…", "Carregando servidores, um momento…", "Загрузка серверов, секунду…", "جارٍ تحميل الخوادم، لحظة…"],
  'snack_no_server': ["Sunucu bulunamadı. Ayarlar'dan listeyi yenile.", "No server found. Refresh the list in Settings.", "Aucun serveur. Actualisez la liste dans Paramètres.", "No hay servidores. Actualiza la lista en Ajustes.", "Nenhum servidor. Atualize a lista em Configurações.", "Серверы не найдены. Обновите список в настройках.", "لا توجد خوادم. حدّث القائمة من الإعدادات."],
  'snack_denied': ["VPN izni verilmedi.", "VPN permission was denied.", "Autorisation VPN refusée.", "Permiso de VPN denegado.", "Permissão de VPN negada.", "Доступ к VPN не предоставлен.", "لم يتم منح إذن VPN."],
  'snack_failed': ["Bağlanılamadı. Başka bir ülke seçip tekrar dene.", "Couldn't connect. Pick another country and try again.", "Connexion impossible. Choisissez un autre pays et réessayez.", "No se pudo conectar. Elige otro país e inténtalo de nuevo.", "Não foi possível conectar. Escolha outro país e tente de novo.", "Не удалось подключиться. Выберите другую страну.", "تعذّر الاتصال. اختر دولة أخرى وحاول مجددًا."],
  'snack_vpn_settings_fail': ["Android VPN ayarları açılamadı.", "Couldn't open Android VPN settings.", "Impossible d'ouvrir les paramètres VPN.", "No se pudieron abrir los ajustes de VPN.", "Não foi possível abrir as configurações de VPN.", "Не удалось открыть настройки VPN.", "تعذّر فتح إعدادات VPN."],
  'settings': ["Ayarlar", "Settings", "Paramètres", "Ajustes", "Configurações", "Настройки", "الإعدادات"],

  // ----------------------------------------------------------- konum seçici
  'choose_location': ["Konum seç", "Choose location", "Choisir un lieu", "Elegir ubicación", "Escolher local", "Выбор локации", "اختر الموقع"],
  'n_servers': ["{n} sunucu", "{n} servers", "{n} serveurs", "{n} servidores", "{n} servidores", "Серверов: {n}", "{n} خادم"],
  'search_hint': ["Ülke ara: Japan, Korea, US…", "Search country: Japan, Korea, US…", "Rechercher un pays : Japan, Korea…", "Buscar país: Japan, Korea, US…", "Buscar país: Japan, Korea, US…", "Поиск страны: Japan, Korea, US…", "ابحث عن دولة: Japan, Korea…"],
  'tab_recommended': ["Önerilen", "Recommended", "Recommandés", "Recomendados", "Recomendados", "Рекомендуемые", "موصى بها"],
  'tab_fastest': ["En hızlı", "Fastest", "Plus rapides", "Más rápidos", "Mais rápidos", "Самые быстрые", "الأسرع"],
  'tab_ping': ["En düşük ping", "Lowest ping", "Ping le plus bas", "Menor ping", "Menor ping", "Наименьший пинг", "أقل تأخير"],
  'tab_favorites': ["★ Favoriler", "★ Favorites", "★ Favoris", "★ Favoritos", "★ Favoritos", "★ Избранное", "★ المفضلة"],
  'fastest_desc': ["Sana en yakın ve en hızlı olanı otomatik seçer", "Automatically picks the closest, fastest one", "Choisit automatiquement le plus proche et rapide", "Elige automáticamente el más cercano y rápido", "Escolhe automaticamente o mais próximo e rápido", "Автоматически выбирает ближайший и быстрый", "يختار الأقرب والأسرع تلقائيًا"],
  'users_n': ["{n} kişi", "{n} users", "{n} utilisateurs", "{n} usuarios", "{n} usuários", "Польз.: {n}", "{n} مستخدم"],
  'fav_add': ["Favorilere ekle", "Add to favorites", "Ajouter aux favoris", "Añadir a favoritos", "Adicionar aos favoritos", "В избранное", "أضف إلى المفضلة"],
  'fav_remove': ["Favorilerden çıkar", "Remove from favorites", "Retirer des favoris", "Quitar de favoritos", "Remover dos favoritos", "Убрать из избранного", "إزالة من المفضلة"],
  'offline': ["Kapalı", "Offline", "Hors ligne", "Caído", "Offline", "Офлайн", "غير متاح"],
  'no_favorites': ["Henüz favori ülke yok. Yıldıza dokunarak ekle.", "No favorite countries yet. Tap the star to add one.", "Aucun pays favori. Touchez l'étoile pour en ajouter.", "Aún no hay países favoritos. Toca la estrella.", "Nenhum país favorito ainda. Toque na estrela.", "Избранных стран нет. Нажмите на звезду.", "لا توجد دول مفضلة بعد. اضغط على النجمة."],

  // ---------------------------------------------------------------- ayarlar
  'sec_general': ["Genel", "General", "Général", "General", "Geral", "Общие", "عام"],
  'language': ["Dil", "Language", "Langue", "Idioma", "Idioma", "Язык", "اللغة"],
  'sec_connection': ["Bağlantı", "Connection", "Connexion", "Conexión", "Conexão", "Подключение", "الاتصال"],
  'auto_connect': ["Açılışta otomatik bağlan", "Connect on launch", "Connexion au démarrage", "Conectar al abrir", "Conectar ao abrir", "Подключаться при запуске", "الاتصال عند التشغيل"],
  'auto_connect_d': ["Uygulama açılınca en hızlı sunucuya bağlanır", "Connects to the fastest server when the app opens", "Se connecte au serveur le plus rapide à l'ouverture", "Se conecta al servidor más rápido al abrir", "Conecta ao servidor mais rápido ao abrir", "Подключается к быстрому серверу при запуске", "يتصل بأسرع خادم عند فتح التطبيق"],
  'auto_switch': ["Akıllı sunucu değiştirme", "Smart server switching", "Changement de serveur intelligent", "Cambio inteligente de servidor", "Troca inteligente de servidor", "Умная смена сервера", "التبديل الذكي للخادم"],
  'auto_switch_d': ["Bağlanamazsa ya da sunucu yavaşsa daha hızlısına geçer", "Switches to a faster server if connecting fails or it's slow", "Passe à un serveur plus rapide en cas d'échec ou de lenteur", "Cambia a uno más rápido si falla o va lento", "Troca por um mais rápido se falhar ou estiver lento", "Переключает на более быстрый сервер при ошибке или медленной скорости", "ينتقل إلى خادم أسرع إذا فشل الاتصال أو كان بطيئًا"],
  'fast_dns': ["Hızlı DNS", "Fast DNS", "DNS rapide", "DNS rápido", "DNS rápido", "Быстрый DNS", "DNS سريع"],
  'fast_dns_d': ["Siteler daha hızlı açılır, DNS sızıntısı önlenir", "Sites open faster and DNS leaks are blocked", "Pages plus rapides, sans fuite DNS", "Webs más rápidas y sin fugas de DNS", "Sites mais rápidos e sem vazamento de DNS", "Сайты быстрее, без утечек DNS", "فتح أسرع للمواقع ومنع تسرب DNS"],
  'kill_on_close': ["Kapatınca bağlantıyı kes", "Disconnect on close", "Déconnecter à la fermeture", "Desconectar al cerrar", "Desconectar ao fechar", "Отключать при закрытии", "قطع الاتصال عند الإغلاق"],
  'kill_on_close_d': ["Uygulama son kullanılanlardan silinince VPN kapanır", "VPN turns off when the app is swiped away", "Le VPN s'arrête quand l'app est fermée", "La VPN se apaga al cerrar la app", "A VPN desliga ao fechar o app", "VPN отключается при закрытии приложения", "يتوقف VPN عند إغلاق التطبيق"],
  'sec_security': ["Güvenlik", "Security", "Sécurité", "Seguridad", "Segurança", "Безопасность", "الأمان"],
  'kill_switch': ["Kill Switch ve Her zaman açık VPN", "Kill Switch & Always-on VPN", "Kill Switch et VPN permanent", "Kill Switch y VPN siempre activa", "Kill Switch e VPN sempre ativa", "Kill Switch и постоянный VPN", "مفتاح الإيقاف وVPN الدائم"],
  'kill_switch_d': ["Android ayarlarında ShadeX için ikisini de aç: VPN koparsa internet kesilir", "Turn both on for ShadeX in Android settings: internet stops if the VPN drops", "Activez les deux pour ShadeX : Internet est coupé si le VPN tombe", "Activa ambos para ShadeX: si cae la VPN, se corta internet", "Ative ambos para o ShadeX: se a VPN cair, a internet para", "Включите оба для ShadeX: без VPN интернет отключится", "فعّل الخيارين لـ ShadeX: ينقطع الإنترنت إذا انقطع VPN"],
  'sec_appearance': ["Görünüm", "Appearance", "Apparence", "Apariencia", "Aparência", "Внешний вид", "المظهر"],
  'notif_speed': ["Bildirimde hızı göster", "Show speed in notification", "Vitesse dans la notification", "Velocidad en la notificación", "Velocidade na notificação", "Скорость в уведомлении", "عرض السرعة في الإشعار"],
  'notif_speed_d': ["İndirme ve yükleme hızını bildirimde gösterir", "Shows download and upload speed in the notification", "Affiche les débits dans la notification", "Muestra descarga y subida en la notificación", "Mostra download e upload na notificação", "Показывает скорость в уведомлении", "يعرض سرعة التنزيل والرفع في الإشعار"],
  'haptics': ["Titreşim", "Vibration", "Vibration", "Vibración", "Vibração", "Вибрация", "الاهتزاز"],
  'haptics_d': ["Düğmeye basınca hafif titreşir", "Light vibration on tap", "Légère vibration au toucher", "Vibración suave al tocar", "Vibração leve ao tocar", "Лёгкая вибрация при нажатии", "اهتزاز خفيف عند الضغط"],
  'sec_servers': ["Sunucular", "Servers", "Serveurs", "Servidores", "Servidores", "Серверы", "الخوادم"],
  'refresh_list': ["Sunucu listesini yenile", "Refresh server list", "Actualiser la liste des serveurs", "Actualizar lista de servidores", "Atualizar lista de servidores", "Обновить список серверов", "تحديث قائمة الخوادم"],
  'refresh_list_d': ["Listeyi indirir ve hızları yeniden ölçer", "Downloads the list and re-measures speeds", "Télécharge la liste et remesure les vitesses", "Descarga la lista y vuelve a medir", "Baixa a lista e mede de novo", "Загружает список и измеряет скорость", "ينزّل القائمة ويعيد قياس السرعات"],
  'clear_favs': ["Favori ülkeleri temizle", "Clear favorite countries", "Effacer les pays favoris", "Borrar países favoritos", "Limpar países favoritos", "Очистить избранные страны", "مسح الدول المفضلة"],
  'favs_cleared': ["Favoriler temizlendi.", "Favorites cleared.", "Favoris effacés.", "Favoritos borrados.", "Favoritos limpos.", "Избранное очищено.", "تم مسح المفضلة."],
  'sec_about': ["Hakkında", "About", "À propos", "Acerca de", "Sobre", "О приложении", "حول"],
  'share_app': ["Uygulamayı paylaş", "Share the app", "Partager l'app", "Compartir la app", "Compartilhar o app", "Поделиться приложением", "شارك التطبيق"],
  'share_app_d': ["İndirme linkini kopyalar", "Copies the download link", "Copie le lien de téléchargement", "Copia el enlace de descarga", "Copia o link de download", "Копирует ссылку для загрузки", "ينسخ رابط التنزيل"],
  'link_copied': ["Link kopyalandı. İstediğin yere yapıştır.", "Link copied. Paste it anywhere.", "Lien copié. Collez-le où vous voulez.", "Enlace copiado. Pégalo donde quieras.", "Link copiado. Cole onde quiser.", "Ссылка скопирована.", "تم نسخ الرابط. الصقه أينما تريد."],
  'privacy': ["Gizlilik", "Privacy", "Confidentialité", "Privacidad", "Privacidade", "Конфиденциальность", "الخصوصية"],
  'privacy_text': [
    "ShadeX hesap istemez, kişisel veri toplamaz ve reklam göstermez.\n\nTrafiğin, seçtiğin ülkedeki sunucuya şifreli tünelle gider. Sunucular gönüllü operatörlerce işletilir ve bağlantı kayıtları bir süre tutulabilir. Bu yüzden ShadeX engelleri aşmak ve halka açık Wi-Fi'da korunmak için uygundur; tam anonimlik gerektiren işler için uygun değildir.",
    "ShadeX requires no account, collects no personal data and shows no ads.\n\nYour traffic travels through an encrypted tunnel to a server in the country you choose. Servers are run by volunteer operators and connection logs may be kept for a while. ShadeX is great for bypassing blocks and staying safe on public Wi-Fi, but it is not meant for tasks that need full anonymity.",
    "ShadeX ne demande aucun compte, ne collecte aucune donnée personnelle et n'affiche aucune publicité.\n\nVotre trafic passe par un tunnel chiffré vers un serveur du pays choisi. Les serveurs sont gérés par des bénévoles et des journaux de connexion peuvent être conservés un temps. ShadeX convient pour contourner les blocages et se protéger sur les Wi-Fi publics, mais pas pour un anonymat total.",
    "ShadeX no pide cuenta, no recopila datos personales ni muestra anuncios.\n\nTu tráfico viaja por un túnel cifrado hasta un servidor del país que elijas. Los servidores los gestionan voluntarios y pueden guardar registros de conexión durante un tiempo. ShadeX es ideal para saltar bloqueos y protegerte en Wi-Fi públicas, pero no para tareas que requieran anonimato total.",
    "O ShadeX não exige conta, não coleta dados pessoais e não mostra anúncios.\n\nSeu tráfego passa por um túnel criptografado até um servidor no país escolhido. Os servidores são mantidos por voluntários e registros de conexão podem ser guardados por um tempo. O ShadeX é ótimo para contornar bloqueios e se proteger em Wi-Fi públicas, mas não para tarefas que exigem anonimato total.",
    "ShadeX не требует аккаунта, не собирает личные данные и не показывает рекламу.\n\nВаш трафик идёт по зашифрованному туннелю на сервер в выбранной стране. Серверы поддерживаются добровольцами, и журналы подключений могут храниться некоторое время. ShadeX подходит для обхода блокировок и защиты в публичных Wi-Fi, но не для задач, требующих полной анонимности.",
    "لا يطلب ShadeX حسابًا ولا يجمع بيانات شخصية ولا يعرض إعلانات.\n\nتمر بياناتك عبر نفق مشفّر إلى خادم في الدولة التي تختارها. يدير الخوادم متطوعون وقد تُحفظ سجلات الاتصال لفترة. يناسب ShadeX تجاوز الحجب والحماية على شبكات Wi-Fi العامة، لكنه غير مخصص للمهام التي تتطلب إخفاء الهوية التام.",
  ],
  'ok': ["Tamam", "OK", "OK", "Aceptar", "OK", "ОК", "حسنًا"],
  'licenses': ["Açık kaynak lisansları", "Open-source licenses", "Licences open source", "Licencias de código abierto", "Licenças de código aberto", "Лицензии открытого ПО", "تراخيص المصادر المفتوحة"],
  'version': ["Sürüm", "Version", "Version", "Versión", "Versão", "Версия", "الإصدار"],
};
