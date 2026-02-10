# 설정/진행 관리 앱 (Android APK)

원하는 것:
- 설정/자료 정리
- 진행상태(아이디어/초안/사용중/완료/수정필요) 색 구분
- 날짜별 진행 로그 기록
- 코딩 없이 APK로 설치

## 가장 쉬운 사용법 (APK 받기)

1) GitHub에 새 저장소(repositiory) 만들기 (Public/Private 상관없음)
2) 이 프로젝트 파일을 업로드(드래그앤드롭) 하거나, zip 풀어서 커밋
3) GitHub에서:
   - Actions 탭 → **Build Android APK (Debug)** 워크플로우 선택
   - **Run workflow** 클릭
4) 빌드가 끝나면 실행 결과(Artifacts)에서:
   - `setting-progress-debug-apk` 다운로드
   - 안에 있는 `app-debug.apk` 를 폰으로 옮겨 설치

## 폰에서 설치
- 설정 → 보안 → "알 수 없는 앱 설치 허용" (브라우저/파일앱)
- APK 탭 → 설치

## 앱 데이터
- 폰 로컬에 저장됩니다(Hive).
- APK를 지우면 앱 데이터가 삭제될 수 있어요.

## 커스터마이즈
- `lib/app_main.dart` 를 수정하면 UI/필드 변경 가능