# Resource Optimization Plan (macOS/Xcode Release)

이 문서는 **macOS 개발환경(Xcode, xcodebuild 기준)**에서
AntiElectricity 릴리즈 용량을 줄이기 위한 실무 가이드입니다.

---

## 1) 목표

- 릴리즈 산출물(.app/.dmg/.zip) 용량 최소화
- 핵심 편집 기능 유지
- 모든 변경은 **측정 → 변경 → 재측정** 루프로 진행

---

## 2) 현재 기준(로컬 분석)

`CotEditor/Resources` 대략:

- `CotEditor.help`: ~7.3MB
- `Assets.xcassets`: ~1.9MB
- `Syntaxes`: ~1.6MB
- `AppIcon.icon`: ~0.62MB

핵심 절감 후보는 **Help 번들 + 에셋 정리**.

---

## 3) macOS 개발환경 체크리스트

## A. 아키텍처 정책 (가장 영향 큼)

- Apple Silicon 전용 배포 가능하면 `arm64 only`
- Intel 지원 필요하면 Universal 유지

확인 명령:

```bash
# 앱 바이너리 아키텍처 확인
lipo -info "AntiElectricity.app/Contents/MacOS/AntiElectricity"
```

---

## B. Release 빌드 설정 (Xcode)

Xcode → Target `AntiElectricity` → Build Settings (Release)

권장값:

- `COPY_PHASE_STRIP = YES`
- `STRIP_INSTALLED_PRODUCT = YES` (보이면)
- `DEAD_CODE_STRIPPING = YES`
- `DEBUG_INFORMATION_FORMAT = dwarf-with-dsym` (유지 가능)
- `SWIFT_COMPILATION_MODE = wholemodule`
- `SWIFT_OPTIMIZATION_LEVEL = -O` 또는 `-Osize` 비교

운영 원칙:
- dSYM은 **배포물에 포함하지 말고** CI/artifact로 별도 보관

---

## C. 리소스 최적화 우선순위

### P1) Help 번들 경량화

선택지:
1. Help 최소화(권장)
2. 릴리즈에서 Help 제외(공격적)

확인 명령:

```bash
du -sh CotEditor/Resources/CotEditor.help
```

### P2) Asset Catalog 정리

- 미사용 아이콘 제거
- 중복 이미지 제거
- 가능한 경우 벡터/PDF 자산 활용

확인 명령:

```bash
du -sh CotEditor/Resources/Assets.xcassets
```

### P3) Syntax 리소스 정책화

- Core 언어 vs Extended 언어 분리 검토
- 사용자 영향 큰 언어는 유지

확인 명령:

```bash
du -sh CotEditor/Resources/Syntaxes
```

### P4) Localizations 정리

- 실제 제공 언어만 유지
- 중복/미사용 locale 제거

---

## 4) 빌드/측정 절차 (macOS CLI)

## 4-1. Release 빌드

```bash
xcodebuild \
  -project CotEditor.xcodeproj \
  -scheme CotEditor \
  -configuration Release \
  -derivedDataPath build/DerivedData \
  build
```

## 4-2. 산출물 위치

```bash
build/DerivedData/Build/Products/Release/AntiElectricity.app
```

## 4-3. 크기 측정

```bash
# 앱 번들 크기
DU_APP="build/DerivedData/Build/Products/Release/AntiElectricity.app"
du -sh "$DU_APP"

# 실행 파일 단일 크기
ls -lh "$DU_APP/Contents/MacOS/AntiElectricity"

# 번들 내부 큰 항목 상위 확인
du -h --max-depth=2 "$DU_APP/Contents/Resources" | sort -h | tail -n 30
```

## 4-4. 압축본 측정(zip)

```bash
cd build/DerivedData/Build/Products/Release
zip -qry AntiElectricity.zip AntiElectricity.app
ls -lh AntiElectricity.zip
```

---

## 5) 릴리즈 전 검증

- [ ] 앱 실행 정상
- [ ] AI 기능(Ollama/Anthropic) 동작
- [ ] 도움말 메뉴 동작(Help 유지 시)
- [ ] 주요 문법 하이라이트 정상
- [ ] 다크 모드 아이콘/심볼 정상

---

## 6) 실행 순서(권장)

1. 기준선 Release 빌드 및 크기 기록
2. Strip/최적화 설정 반영
3. Help 경량화
4. Asset 정리
5. Syntax/Localization 정리
6. 최종 빌드 + zip 측정
7. 릴리즈 노트에 용량 변화 기록

---

## 7) 측정 템플릿

```text
[Baseline]
- Commit:
- Xcode:
- macOS:
- Config: Release
- Arch: arm64 / universal
- .app size:
- .zip/.dmg size:

[Change #1]
- What changed:
- .app size:
- .zip/.dmg size:
- Delta:
- Side effect:
```

---

## 8) 권장 시나리오

### 보수적(기능 영향 최소)
- strip + dSYM 분리 + Help 최소화 + Assets 정리

### 공격적(용량 최우선)
- arm64-only + Help 제외 + 강한 리소스 정리

---

## 9) 원칙

- 감으로 지우지 말고 항상 측정 기반으로 진행
- 사용자 가치가 낮은 중복/미사용 리소스부터 제거
- 용량 최적화는 릴리즈마다 반복하는 운영 작업
