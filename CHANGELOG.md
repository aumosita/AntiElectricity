# Change Log

## AntiElectricity

> AntiElectricity는 CotEditor 7.0.0-alpha를 기반으로 포크되었습니다.
> CotEditor의 전체 변경 이력은 [CotEditor CHANGELOG](https://github.com/coteditor/CotEditor/blob/main/CHANGELOG.md)를 참조하세요.

---

7.0.0-alpha (unreleased)
--------------------------

### New Features (AntiElectricity)

- AI/LLM 통합: Ollama, Anthropic Claude, OpenAI, GitHub Copilot 프로바이더 지원
- AI Chat 패널: 에디터 옆에서 AI와 대화하며 코드/텍스트 편집
- 프리셋 프롬프트 시스템: 맞춤법 교정, 글 고쳐쓰기, 코드 생성/수정/설명 등
- 자유 프롬프트 (⌘⇧P): 원하는 지시를 바로 입력
- Inline Diff: VS Code 스타일의 인라인 코드 수정 제안 (Accept/Reject)
- Claude OAuth 로그인 지원
- AI 설정 패널 (Settings → AI)

### Inherited from CotEditor 7.0.0

- Tree-sitter 기반 구문 강조 및 아웃라인 추출 (20개 언어)
- CotEditor Syntax 포맷 (새로운 구문 정의 형식)
- 구문 기반 스마트 들여쓰기
- 검색 결과 현재 위치 표시 (예: "2/5")
