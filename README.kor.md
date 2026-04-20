# homebrew-wine-dxmt

wine + dxmt + steam 설치를 하나로 통합한 brew cask 입니다.  
DJMax, EZ2ON 의 실행이 안되는 버그를 막고, 스팀 설정 및 여러 설정을 미리 넣어둔 스크립트로 보면 됩니다.

자세한 패치 내역은 [TECHNICAL.md](./TECHNICAL.md) 을 참고해주세요.

- wine 11.6_1
- dxmt v0.74

## 설치 방법

```bash
# Steam까지 모두 설치 (권장)
brew tap zzzz465/homebrew-wine-dxmt
brew install --cask wine-dxmt-steam

# 이미 Steam이 설치된 경우
brew tap zzzz465/homebrew-wine-dxmt
WINE_DXMT_PREFIX=/path/to/your/steam/prefix brew install --cask wine-dxmt-steam
```

## 사용법

```bash
# Steam 실행
wine-dxmt-steam

# 게임 바로 실행 (예: DJMax)
wine-dxmt-steam -applaunch 960170

# 종료는 일반적으로 스팀의 종료 버튼 (Exit) 을 누르면 됩니다. 안꺼지면 아래 커맨드를 써주세요.
# FYI: 우클릭 후 종료할 경우 재시작됩니다.
wine-dxmt-steam shutdown
```
