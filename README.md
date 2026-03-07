# ⚡ AntiElectricity

**AntiElectricity**는 [CotEditor](https://coteditor.com)를 기반으로 한 macOS 네이티브 텍스트 에디터입니다.
CotEditor의 가볍고 아름다운 편집 환경 위에 **AI/LLM 기능**을 결합하여,
글쓰기와 코딩을 새로운 방식으로 보조하는 에디터를 지향합니다.

- **요구 사양**: macOS Sequoia 15 이상
- **제작자**: Yong Lee
- **기반 프로젝트**: [CotEditor](https://github.com/coteditor/CotEditor) by 1024jp

---

## 핵심 기능

### 🤖 AI/LLM 통합

**Ollama**(로컬 LLM)와 **Anthropic Claude API**를 지원하여 텍스트를 직접 수정·생성할 수 있습니다.

- **프리셋 프롬프트 시스템** — 자주 쓰는 AI 명령을 프리셋으로 저장하고, 메뉴·단축키로 즉시 실행
- **예제 프리셋 제공** — 맞춤법 교정, 글 고쳐쓰기, 옛한글 번역, 코드 생성/수정/설명 등 6개 예제를 한 번에 가져오기
- **자유 프롬프트** — 정해진 프리셋 없이 원하는 지시를 바로 입력 (⌘⇧P)
- **수정 승인/거부** — AI가 수정한 결과를 살펴본 후 Accept 또는 Reject
- **다중 접근 방식**:
  - 메뉴바 **AI** 메뉴
  - 툴바 **✨ 버튼** (드롭다운)
  - 우클릭 **컨텍스트 메뉴**

### ✏️ CotEditor에서 물려받은 기능

- 50개 이상의 프로그래밍 언어 구문 강조 (Tree-sitter 기반)
- 다양한 텍스트 인코딩 지원 (유니코드·한국어 인코딩 우선 배치)
- 정규표현식 검색/치환
- 스크립트 자동화 (AppleScript, Shell, Python 등)
- 분할 편집기
- macOS 네이티브 UI

---

### 🔌 지원 프로바이더

| 프로바이더 | 유형 | 주요 모델 |
|-----------|------|----------|
| **Ollama** | 로컬 | Llama, Qwen, Mistral 등 |
| **Anthropic** | 클라우드 API | Claude Sonnet 4, Haiku 4, 3.5 Sonnet/Haiku, Opus |

---

## 비전

AntiElectricity는 **"생각하는 텍스트 에디터"**를 목표로 합니다.

1. **로컬 우선** — Ollama를 통해 인터넷 연결 없이도 AI 기능 사용 가능
2. **사용자 제어** — AI가 무엇을 수정하든 최종 결정은 사용자에게
3. **확장 가능** — Ollama, Anthropic에 이어 OpenAI 등 추가 프로바이더 확장 예정
4. **한국어 친화** — 한국어 맞춤법 교정, 옛한글(ㆍ, ㆁ, ㅸ) 번역 등 한국어 특화 기능

---

## 빌드 방법

### 로컬 빌드 (Ad-hoc)

```bash
# Xcode에서 열기
open CotEditor.xcodeproj

# 또는 커맨드라인 빌드
xcodebuild -project CotEditor.xcodeproj -scheme CotEditor -configuration Release build
```

빌드된 앱은 DerivedData의 `Build/Products/Release/AntiElectricity.app`에 생성됩니다.

### 개발 환경

- macOS Tahoe 26 / Xcode 26.3
- Swift 6.2
- Sandbox + Hardened Runtime

---

## AI 설정

### Ollama (로컬)
1. [Ollama](https://ollama.ai)를 설치하고 모델을 다운로드합니다. (`ollama pull qwen3:8b` 등)
2. Settings → **AI** → Provider: **Ollama** 선택
3. Server URL 확인, **Test** 버튼으로 연결 확인, 모델 선택

### Anthropic (클라우드)
1. [Anthropic Console](https://console.anthropic.com)에서 API 키 발급
2. Settings → **AI** → Provider: **Anthropic** 선택
3. API Key 입력, 모델 선택 (Claude Sonnet 4 추천)

> **공통**: **Import Examples** 버튼으로 예제 프리셋을 가져올 수 있습니다.

---

## 감사의 말

AntiElectricity는 [**CotEditor**](https://coteditor.com)를 포크하여 만들어졌습니다.

CotEditor는 오랜 시간 동안 macOS 생태계에서 가장 아름답고 신뢰할 수 있는 오픈소스 텍스트 에디터로 자리잡아 온 프로젝트입니다. 1024jp를 비롯한 CotEditor 기여자들의 수년간의 헌신적인 작업이 없었다면 이 프로젝트는 존재할 수 없었을 것입니다. 진심으로 감사드립니다.

> CotEditor © 2005-2009 nakamuxu, © 2011, 2014 usami-k, © 2013-2026 1024jp
> Licensed under the Apache License, Version 2.0

---

## 라이선스

소스 코드는 **Apache License 2.0** 조건에 따라 라이선스가 부여됩니다.
이미지 리소스는 [Creative Commons BY-NC-ND 4.0](https://creativecommons.org/licenses/by-nc-nd/4.0/)에 따릅니다.
자세한 내용은 [LICENSE](LICENSE)를 참조하세요.
