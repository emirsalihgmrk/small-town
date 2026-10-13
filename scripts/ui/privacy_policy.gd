class_name PrivacyPolicy
extends RefCounted
## Gizlilik politikasının oyun içindeki metni (Ebeveyn Köşesi). Yayındaki sayfanın aynısıdır:
## https://kidolab-studio.github.io/linasfarm-privacy-policy/ (repo: kidolab-studio/linasfarm-privacy-policy).
## Biri değişince öteki de, iki dildeki yürürlük tarihiyle birlikte güncellenmeli.
## Telefonun dili Türkçeyse Türkçe, değilse İngilizce gösterilir.

const URL: String = "https://kidolab-studio.github.io/linasfarm-privacy-policy/"
const EMAIL: String = "emirsalihgumruk@gmail.com"

const TR: Dictionary = {
	"title": "Gizlilik politikası",
	"date": "Yürürlük tarihi: 13 Ekim 2026",
	"intro": "Lina'nın Çiftliği (İngilizce adıyla Lina's Farm), kidolab tarafından 5–6 yaş çocuklar için geliştirilmiş bir Android oyunudur. Bu politika, oyunun kişisel verilere nasıl yaklaştığını açıklar.\n\nKısaca: Oyun hiçbir kişisel veri toplamaz, saklamaz ya da paylaşmaz. İnternete bağlanmaz, reklam göstermez, satın alma istemez.",
	"sections": [
		["Toplanmayan bilgiler", "Oyun sizden ya da çocuğunuzdan hiçbir kişisel bilgi istemez ve toplamaz. Ad, e-posta, konum, fotoğraf, ses, rehber, cihaz kimlikleri ya da reklam kimliği gibi bilgilere erişmez.\n• Oyun internete bağlanmaz; internet izni yoktur.\n• Reklam, analiz ya da istatistik aracı, uygulama içi satın alma, hesap, sohbet ve sosyal paylaşım yoktur.\n• Oyun hiçbir Android izni istemez (kamera, mikrofon, konum, depolama vb.).\n• Veri toplayan üçüncü taraf hizmet kullanılmaz. Oyun açık kaynaklı Godot oyun motoruyla yapılmıştır; motor veri toplamaz."],
		["Cihazda kalan bilgiler", "Çocuğunuz kaldığı yerden devam edebilsin diye oyunun ilerlemesi (sepetteki ürünler, kumbaradaki paralar, dükkândan alınan süsler, ses ayarları gibi) yalnızca cihazın içinde, oyuna ait klasörde saklanır. Bu bilgiler kişisel veri içermez, hiçbir yere gönderilmez ve bulut yedeklemesine dahil edilmez. Oyunu kaldırdığınızda ya da Android ayarlarından oyunun verilerini temizlediğinizde silinir."],
		["Çocukların gizliliği", "Oyun çocuklar için tasarlanmıştır ve kişisel veri işlemez. Bu nedenle ABD Çocukların Çevrimiçi Gizliliğini Koruma Yasası (COPPA), AB Genel Veri Koruma Tüzüğü (GDPR) ve 6698 sayılı Kişisel Verilerin Korunması Kanunu (KVKK) kapsamında ebeveyn onayı gerektiren bir veri işleme yapılmaz. Yetişkinlere yönelik bölümler (ses ayarları, lisans bilgileri ve bu politika), çocukların yanlışlıkla açmaması için basılı tutularak açılan \"Ebeveyn Köşesi\"ndedir."],
		["Google Play", "Oyunu Google Play'den indirdiğinizde Google, indirme ve hesabınızla ilgili bilgileri kendi gizlilik politikasına göre işler. Google Play bize yalnızca indirme sayısı ve uygulama çökme raporları gibi kimliği belirlemeyen, toplu istatistikler sunar; bu bilgilerden sizi ya da çocuğunuzu tanıyamayız."],
		["Değişiklikler", "Bu politikayı değiştirirsek güncel hali internet sayfamızda, yeni yürürlük tarihiyle yayımlanır. Oyun ileride herhangi bir veri toplamaya başlayacak olursa bunu önceden açıkça belirtir, gerektiğinde ebeveyn onayı alırız.\nGüncel hali: " + URL],
		["İletişim", "Sorularınız için bize yazabilirsiniz: " + EMAIL],
	],
}

const EN: Dictionary = {
	"title": "Privacy policy",
	"date": "Effective date: October 13, 2026",
	"intro": "Lina's Farm (Lina'nın Çiftliği in Turkish) is an Android game for children aged 5–6, developed by kidolab. This policy explains how the game treats personal data.\n\nIn short: the game does not collect, store or share any personal data. It does not connect to the internet, show ads or ask for purchases.",
	"sections": [
		["Information we do not collect", "The game does not ask for or collect any personal information from you or your child. It does not access names, email addresses, location, photos, audio, contacts, device identifiers or advertising IDs.\n• The game does not connect to the internet and has no internet permission.\n• There are no ads, analytics or tracking tools, in-app purchases, accounts, chat or social sharing.\n• The game requests no Android permissions (camera, microphone, location, storage, etc.).\n• No third-party services that collect data are used. The game is built with the open-source Godot game engine, which does not collect data."],
		["Information kept on the device", "So that your child can continue where they left off, game progress (such as items in the basket, coins in the piggy bank, decorations bought in the shop and sound settings) is stored only on the device, in the game's own folder. This information contains no personal data, is never sent anywhere and is not included in cloud backups. It is deleted when you uninstall the game or clear its data in Android settings."],
		["Children's privacy", "The game is designed for children and does not process personal data. Therefore no data processing that would require parental consent under the U.S. Children's Online Privacy Protection Act (COPPA), the EU General Data Protection Regulation (GDPR) or Turkey's Personal Data Protection Law No. 6698 (KVKK) takes place. Sections meant for adults (sound settings, license information and this policy) are in the \"Parents' Corner\", which opens only with a long press so that children do not open it by accident."],
		["Google Play", "When you download the game from Google Play, Google processes information about the download and your account under its own privacy policy. Google Play only provides us with aggregated, non-identifying statistics such as install counts and app crash reports; we cannot identify you or your child from them."],
		["Changes", "If we change this policy, the updated version will be published on our website with a new effective date. Should the game ever start collecting any data, we will state this clearly in advance and obtain parental consent where required.\nCurrent version: " + URL],
		["Contact", "If you have any questions, please write to us: " + EMAIL],
	],
}


## Telefonun diline göre metin: {"title", "date", "intro", "sections": [[başlık, gövde], ...]}.
static func for_device() -> Dictionary:
	return TR if TranslationServer.get_locale().get_slice("_", 0) == "tr" else EN
