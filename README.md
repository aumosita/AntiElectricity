# ⚡ AntiElectricity

**AntiElectricity**는 [CotEditor](https://coteditor.com)를 기반으로 한 macOS 네이티브 텍스트 에디터입니다.
CotEditor의 가볍고 아름다운 편집 환경 위에 **AI/LLM 기능**을 결합하여,
글쓰기와 코딩을 새로운 방식으로 보조하는 에디터를 지향합니다.

- **요구 사양**: macOS Sequoia 15 이상
- **제작자**: Yong Lee
- **기반 프로젝트**: [CotEditor](https://github.com/coteditor/CotEditor) by 1024jp

---

## 핵심 AI 기능

AntiElectricity는 두 가지 방식으로 AI를 활용합니다:
**① 텍스트 블록을 선택해 프롬프트를 적용하는 방식**과 **② AI 채팅 패널을 통한 대화형 편집**입니다.

### 🎯 프롬프트 기반 텍스트 변환

텍스트를 선택하고 프롬프트를 적용하면, AI가 선택된 텍스트를 지시에 따라 변환합니다.

**사용 방법 — 3가지 접근 경로:**

| 방법 | 설명 |
|------|------|
| 메뉴바 **AI** 메뉴 | 프리셋 목록에서 선택 |
| 툴바 **✨ 버튼** | 드롭다운으로 프리셋 선택 |
| 우클릭 컨텍스트 메뉴 | 선택 영역 근처에 팝업 |

**작동 흐름:**

1. 에디터에서 변환하고 싶은 텍스트를 선택 (드래그 또는 ⌘A)
2. AI 메뉴 / 툴바 / 우클릭 중 하나로 프리셋 선택
3. AI가 결과를 팝오버로 표시
4. **Accept** (⌘↩) 또는 **Reject** (Esc) 로 결정

### 📝 프리셋 프롬프트 시스템

자주 쓰는 AI 명령을 프리셋으로 저장하고 재사용할 수 있습니다.

**기본 제공 예제 프리셋 (Import Examples 버튼으로 가져오기):**

| 프리셋 | 설명 |
|--------|------|
| 맞춤법 교정 | 한국어/영어 맞춤법·문법을 교정 |
| 고쳐쓰기 | 문체를 개선하면서 의미 유지 |
| 옛한글 번역 | 현대 한국어 → 조선시대 옛한글 (ㆍ, ㆁ, ㅸ 등) |
| 코드 생성 | 주석/설명을 바탕으로 코드 생성 |
| 코드 수정 | 기존 코드의 버그 수정 및 개선 |
| 코드 설명 | 코드를 한국어로 상세 설명 |

사용자가 원하는 프리셋을 직접 추가·편집·삭제할 수 있습니다 (설정 → AI).

### 💬 자유 프롬프트 (⌘⇧P)

프리셋 없이, 원하는 지시를 직접 입력하여 즉석에서 실행할 수 있습니다.

```
예: "영어로 번역해", "표 형식으로 정리해", "3줄로 요약해"
```

### 🗨️ AI 채팅 패널

에디터 오른쪽에 열리는 채팅창을 통해 AI와 대화하면서 문서를 편집할 수 있습니다.

**주요 기능:**

- **문맥 인식** — 현재 문서의 전체 텍스트와 구문(Syntax) 정보를 AI에게 자동 전달
- **SEARCH/REPLACE 블록** — AI가 문서 수정을 제안할 때 `<<<SEARCH` / `===` / `REPLACE>>>` 형식의 편집 블록을 반환하면, **Apply** 버튼으로 해당 부분만 정밀하게 교체
- **인라인 미리보기** — 편집 블록을 적용하기 전에 에디터에서 변경 내용을 하이라이트로 미리 확인
- **글자 크기 동기화** — 에디터의 글자 크기와 채팅 패널의 글자 크기가 자동 동기화
- **복수 편집 블록** — 하나의 AI 응답에 여러 수정 블록이 포함될 수 있으며, 각각 독립적으로 적용 가능

**사용 예시:**

```
사용자: "이 코드에서 에러 핸들링을 추가해줘"
AI: 설명 + SEARCH/REPLACE 블록 반환
사용자: [Apply] 버튼 클릭 → 에디터에 자동 반영
```

---

## 지원 프로바이더

| 프로바이더 | 유형 | 주요 모델 |
|-----------|------|----------|
| **Ollama** | 로컬 | Llama, Qwen, Mistral 등 |
| **Anthropic** | 클라우드 API | Claude Sonnet 4, Haiku 4, 3.5 Sonnet/Haiku, Opus |
| **OpenAI** | 클라우드 API | GPT-4o, GPT-4, GPT-3.5 등 |
| **GitHub Copilot** | 클라우드 | Copilot 모델 |

---

## 기타 기능

### 🆕 새 탭 시작 화면

새 탭을 열면 **새 문서 만들기(N)**와 **불러오기(O)** 버튼이 표시됩니다.
키보드만으로도 조작 가능하며 (N/O 키), 입력기 언어에 상관없이 물리 키 위치로 동작합니다.
설정에서 기존 방식(빈 문서 즉시 열기)으로 전환할 수 있습니다.

### 📊 상태 표시줄 카운트 피커

하단 상태 표시줄의 글자수 표시를 클릭하면 **글자수 / 공백 제외 / 단어 / 줄 / 200자 원고지 매수** 중에서 전환할 수 있습니다.

### ✏️ CotEditor에서 물려받은 기능

- 50개 이상의 프로그래밍 언어 구문 강조 (Tree-sitter 기반)
- 다양한 텍스트 인코딩 지원 (유니코드·한국어 인코딩 우선 배치)
- 정규표현식 검색/치환
- 스크립트 자동화 (AppleScript, Shell, Python 등)
- 분할 편집기
- macOS 네이티브 UI

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

## 비전

AntiElectricity는 **"생각하는 텍스트 에디터"**를 목표로 합니다.

1. **로컬 우선** — Ollama를 통해 인터넷 연결 없이도 AI 기능 사용 가능
2. **사용자 제어** — AI가 무엇을 수정하든 최종 결정은 사용자에게
3. **확장 가능** — Ollama, Anthropic에 이어 OpenAI, GitHub Copilot 등 추가 프로바이더 확장 예정
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
