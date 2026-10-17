# 새 가계부마다 생성하며, 설명은 영수증 품목 분류에도 사용한다.
DEFAULT_CATEGORIES: list[tuple[str, str]] = [
    ("Food", "직접 조리하거나 섭취할 식료품. 예: 고기, 채소, 과일, 음료, 스낵. 외식·배달은 Dining, 세제·휴지는 Living."),
    ("Living", "집에서 쓰는 생활용품·소모품. 예: 세제, 휴지, 샴푸, 수건, 주방용품, 수납용품, 가구, 가전. 옷은 Fashion, 전자기기는 Electronics."),
    ("Electronics", "전자기기·주변기기 하드웨어. 예: 폰, 노트북, 모니터, 이어폰, 충전기, 게임 콘솔. 게임 콘텐츠는 Entertainment, 디지털 구독은 Subscription, 가전은 Living."),
    ("Fashion", "몸에 걸치는 물건. 예: 옷, 신발, 가방, 액세서리, 화장품. 세탁 서비스는 Etc."),
    ("Dining", "조리된 음식·음료. 예: 레스토랑, 카페, 배달, 술집. 마트에서 산 식재료는 Food."),
    ("Transport", "일상 이동 비용. 예: 개스, 대중교통, Uber/Lyft, 주차, 차량 정비. 여행지 항공·숙박은 Travel."),
    ("Subscription", "반복 결제 디지털·멤버십 서비스. 예: Netflix, Spotify, iCloud, 짐 멤버십, Amazon Prime. 일회성 구매는 해당 카테고리로 분류."),
    ("Utilities·Bills", "주거 관련 고정 요금. 예: 전기, 수도, 주거용 개스, 인터넷, 휴대폰 요금. 렌트는 MVP 범위 밖."),
    ("Health", "건강·의료 비용. 예: 병원, 약국, 보험 본인부담금, 영양제. 짐 멤버십은 Subscription."),
    ("Entertainment", "여가·취미 소비. 예: 영화, 공연, 게임, 책, 취미용품. 반복 결제형 콘텐츠는 Subscription."),
    ("Travel", "여행 관련 지출. 예: 항공권, 호텔, 여행지 액티비티. 일상 이동은 Transport."),
    ("Etc", "다른 카테고리에 속하지 않는 지출. 예: 선물, 기부, 수수료, 분류가 애매한 지출."),
]
