# TinyMCE – fork Compan

Fork [tinymce/tinymce](https://github.com/tinymce/tinymce) utrzymywany po to, żeby dostarczać TinyMCE 7 z nowszym, wbudowanym
DOMPurify niż w oficjalnych wydaniach. Kod jest publiczny zgodnie z licencją GPL-2.0-or-later.

| Wydanie | Baza | DOMPurify | Gałąź |
|---|---|---|---|
| `7.9.3-compan.1` (wersja npm `7.9.3+compan.1`) | `7.9.3` | 3.2.6 → 3.4.18 | `compan/7.9.3-dompurify-3.4.18` |

Paczka jest używana w `docusafe-web-ui` i `dockind3-ui/dockind`:

```json
"tinymce": "https://github.com/NawrockiK/tinymce_compan/releases/download/7.9.3-compan.1/tinymce-7.9.3-compan.1.tgz"
```

## Jak powstaje paczka

TinyMCE wkleja DOMPurify do zbudowanych plików (`tinymce.js` i `themes/silver/theme.js` oraz ich wersje `.min.js`),
więc `overrides` w npm nie podmienia tej kopii. Pakiet `modules/tinymce` jest `private`, a paczkę npm Tiny publikuje
własnym procesem. Dlatego `compan/pack.sh`:

1. pobiera oficjalną paczkę `tinymce@<baza>` z npm,
2. podmienia w niej tylko pliki zawierające DOMPurify oraz `notices.txt` na wynik builda z tego repozytorium,
3. ustawia `version` i `repository` w `package.json`,
4. sprawdza, że w paczce jest wyłącznie wersja DOMPurify z `modules/tinymce/package.json`, a liczba plików
   zgadza się z oficjalną paczką,
5. pakuje wynik przez `npm pack`.

Pozostałe pliki (pluginy, skórki, ikony, typy) są oficjalne i niezmienione.

## Wersjonowanie

Wersja paczki ma postać `<baza>+compan.N`, np. `7.9.3+compan.2`. Nie używaj sufiksu `-compan.N`: to wersja
prerelease, która nie spełnia zakresu `^7.0.0` wymaganego przez `@tinymce/tinymce-react`, przez co `npm install`
kończy się błędem `ERESOLVE`. Tag i nazwa pliku używają `-` zamiast `+` (`7.9.3-compan.2`, `tinymce-7.9.3-compan.2.tgz`).

## Nowe wydanie (np. kolejna wersja DOMPurify)

Wymagania: Linux/WSL, Node 20, yarn 1 (`npm i -g yarn`), git.

```bash
git checkout compan/7.9.3-dompurify-3.4.18          # albo nowa gałąź od tagu bazowego Tiny
# 1. w modules/tinymce/package.json ustaw dokładną wersję "dompurify": "X.Y.Z"
# 2. zaktualizuj w yarn.lock tylko blok dompurify (version, resolved, integrity z `npm view dompurify@X.Y.Z dist`)
# 3. zaktualizuj wersję DOMPurify w NOTICES.txt i modules/tinymce/src/core/text/tinymce-license-headers.js
# 4. dopisz wpis do modules/tinymce/CHANGELOG.md (wymóg GPL: opis zmiany)
compan/pack.sh 7.9.3+compan.2 --build               # wynik: ../tinymce_compan-dist/tinymce-7.9.3-compan.2.tgz
git commit -am "Bump bundled DOMPurify -> X.Y.Z"
git tag 7.9.3-compan.2
git push origin HEAD 7.9.3-compan.2
gh release create 7.9.3-compan.2 ../tinymce_compan-dist/tinymce-7.9.3-compan.2.tgz --title 7.9.3-compan.2
```

Następnie w projektach podmień URL w `package.json` i uruchom `npm install`.

Uwagi:

- Bazy `7.9.1` i starszych nie da się podbić w ten sposób: używają łatki Tiny `patches/dompurify+3.2.4.patch`,
  która nie nakłada się na nowsze DOMPurify. Tiny usunął ją w `7.9.2` (TINY-12056).
- Nie podmieniaj pliku w istniejącym release – zmienia to sumę kontrolną zapisaną w `package-lock.json` projektów
  (`EINTEGRITY`). Każda zmiana to nowe `N`.
- `yarn install` działa z `--frozen-lockfile` (`.yarnrc`), więc `yarn.lock` trzeba zmieniać ręcznie albo
  bez tej opcji, pilnując, żeby nie zmieniły się inne wpisy.
