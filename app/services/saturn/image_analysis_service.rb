# GPT-4o ile resim analizi yapan servis
# Ürün resimleri veya müşteri gönderdiği resimler için kullanılır
class Saturn::ImageAnalysisService
  ANALYSIS_PROMPT = <<~PROMPT
    Bu bir e-ticaret ürün resmidir. Resmi analiz et ve aşağıdaki bilgileri Türkçe olarak ver:

    1. Ürün türü (kolye, yüzük, bileklik, küpe, saat vb.)
    2. Malzeme görünümü (altın, gümüş, çelik, deri vb.)
    3. Taş varsa: rengi, şekli, türü
    4. Renk ve ton
    5. Stil (minimalist, gösterişli, vintage, modern vb.)
    6. Özel detaylar (zincir tipi, kapama türü, desen vb.)

    SADECE ürünü tanımlayan kısa, arama için optimize edilmiş bir metin yaz.
    Örnek: "Gümüş renkli zincir kolye, oval siyah taş, minimalist tasarım"

    Cevabını sadece tanımlama metni olarak ver, başka açıklama ekleme.
  PROMPT

  CUSTOMER_IMAGE_PROMPT = <<~PROMPT
    Müşteri bu resmi gönderdi ve benzer bir ürün arıyor. Resmi analiz et.

    Eğer bu bir ürün resmi ise (takı, aksesuar, giyim vb.):
    - Ürün türünü belirle
    - Renk, malzeme, stil gibi özellikleri tanımla
    - Arama için optimize edilmiş kısa bir tanım yaz

    Eğer ürün resmi değilse:
    - "ÜRÜN_DEĞİL" yaz

    Cevabını sadece tanımlama metni olarak ver.
    Örnek: "Altın renkli ince zincir bileklik, küçük kalp charm, zarif tasarım"
  PROMPT

  def initialize(account: nil)
    @account = account
    @api_key = fetch_api_key
  end

  # Ürün resmini analiz et (sync sırasında kullanılır)
  def analyze_product_image(image_url)
    return nil if image_url.blank?
    return nil if @api_key.blank?

    analyze_image(image_url, ANALYSIS_PROMPT)
  end

  # Müşteri gönderdiği resmi analiz et
  def analyze_customer_image(image_url)
    return nil if image_url.blank?
    return nil if @api_key.blank?

    result = analyze_image(image_url, CUSTOMER_IMAGE_PROMPT)
    return nil if result&.include?('ÜRÜN_DEĞİL')

    result
  end

  private

  def fetch_api_key
    @account&.openai_api_key.presence ||
      InstallationConfig.find_by(name: 'SATURN_OPEN_AI_API_KEY')&.value
  end

  def analyze_image(image_url, prompt)
    client = OpenAI::Client.new(access_token: @api_key)

    response = client.chat(
      parameters: {
        model: 'gpt-4o-mini', # Hızlı ve ucuz, resim analizi için yeterli
        messages: [
          {
            role: 'user',
            content: [
              { type: 'text', text: prompt },
              { type: 'image_url', image_url: { url: image_url, detail: 'low' } }
            ]
          }
        ],
        max_tokens: 200,
        temperature: 0.3
      }
    )

    response.dig('choices', 0, 'message', 'content')&.strip
  rescue StandardError => e
    Rails.logger.error "[IMAGE ANALYSIS] Error: #{e.message}"
    nil
  end
end

