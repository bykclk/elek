# Elek — Gizlilik Politikası

**Yürürlük tarihi:** 14 Temmuz 2026

Elek, şifreli DNS ile reklamları ve izleyicileri sistem genelinde engelleyen bir
iOS uygulamasıdır. Gizliliğin uygulamanın bütün amacı olması nedeniyle politika
kısadır: **Elek hiçbir kişisel veriyi toplamaz, saklamaz, satmaz veya paylaşmaz
ve hiçbir kayıt (log) tutmaz.** Hesap yok, analitik yok, reklam yok, izleme yok.

## Elek nasıl çalışır ve verilerinize ne olur

- **Elek şifreli DNS yapılandırır — bir VPN değildir.** Elek'i açtığınızda bir
  DNS-over-HTTPS yapılandırması kurar ve Ayarlar'dan açmanızı ister. iOS bundan
  sonra cihazınızın DNS sorgularını — ve yalnızca DNS sorgularını — Elek'in
  çözücüsüne gönderir. Asıl trafiğiniz (açtığınız sayfalar, gönderip aldığınız
  mesaj ve dosyalar) Elek'ten **geçmez**.
- **DNS sorgularınız Elek'in çözücüsü tarafından yanıtlanır.** Çözücü,
  Cloudflare'ın ağında çalışan küçük, açık kaynaklı bir programdır. Her sorguda
  yalnızca istenen alan adını görür (örneğin `example.com`), bunun bilinen bir
  reklam/izleyici alanı olup olmadığına karar verir ve ya engeller (`NXDOMAIN`
  "böyle bir alan yok" yanıtı döner) ya da Cloudflare'ın herkese açık DNS'ine
  iletip sonucu döndürür.
- **Çözücü hiçbir kayıt tutmaz.** Baktığınız alan adlarını, IP adresinizi veya
  başka hiçbir şeyi kaydetmez. Tüm kaynak kodu herkese açıktır
  ([github.com/bykclk/elek](https://github.com/bykclk/elek), `worker/` klasörü),
  böylece bağımsız olarak doğrulanabilir.
- **Çözücünün görebildiği ve göremediği.** DNS yalnızca alan adı taşıdığı için
  çözücü teknik olarak cihazınızın baktığı alan adlarını, isteğin geldiği ağ
  adresini ve zamanı görür. Trafiğinizin **içeriğini**, ziyaret ettiğiniz tam
  adresleri (yolları), mesajlarınızı veya uygulamalarınızın içindeki hiçbir şeyi
  **asla** göremez. Elek bunların **hiçbirini** kaydetmez veya saklamaz.
- **İzin verilen sorgular şifreli çözülür.** Engellenmeyen alan adları,
  şifreli bir bağlantı üzerinden Cloudflare'ın herkese açık DNS'ine iletilir ve
  [Cloudflare'ın gizlilik politikası](https://www.cloudflare.com/privacypolicy/)
  kapsamında işlenir.
- **Hesap yok, tanımlayıcı yok.** Elek oturum açma gerektirmez ve size hiçbir
  tanımlayıcı atamaz.

## Topladığımız veriler

Hiçbiri. Elek kişisel veri, reklam tanımlayıcısı, iletişim bilgisi, konum veya
kullanım analitiği toplamaz. Üçüncü taraf analitik, reklam veya çökme-raporlama
SDK'sı içermez. Elek sizi uygulamalar veya web siteleri arasında izlemez. Elek'in
çözücüsüne gönderilen DNS sorguları yalnızca anlık olarak yanıtlanmak için
kullanılır ve asla kaydedilmez veya saklanmaz.

## Üçüncü taraf hizmetler

- **Cloudflare** — Elek'in DNS çözücüsünü barındırır ve izin verilen sorguları
  çözmek için üst-kaynak (upstream) sağlayıcıdır.
- **HaGeZi listesi** — Elek'in çözücüsünün uyguladığı, açık kaynaklı reklam/
  izleyici alan adı listesi
  ([github.com/hagezi/dns-blocklists](https://github.com/hagezi/dns-blocklists)).

Elek geliştiricisine hiçbir veri göndermez ve geliştirici hiçbir kayıt tutmaz.

## Çocuklar

Elek çocuklara yönelik değildir ve hiç kimseden veri toplamaz.

## Değişiklikler

Bu politika değişirse, güncel sürüm yeni yürürlük tarihiyle burada yayımlanır.

## İletişim

Sorular: **omerbuyukcelik@gmail.com**
