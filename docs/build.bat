@echo off
REM ============================================
REM  Build script - UNIBA Collab Project Docs
REM  Based on toptesi class
REM  Usage: build.bat [clean]
REM ============================================

if "%1"=="clean" goto clean

echo [BUILD] Compiling LaTeX documentation (toptesi)...
echo.

REM First pass
pdflatex -interaction=nonstopmode main.tex
if errorlevel 1 (
    echo [ERROR] pdflatex first pass failed!
    pause
    exit /b 1
)

REM Bibliography (bibtex, not biber - matches bibliographystyle{plain})
bibtex main
if errorlevel 1 (
    echo [WARNING] bibtex failed (bibliography may not be updated)
)

REM Second pass
pdflatex -interaction=nonstopmode main.tex

REM Third pass (for cross-references)
pdflatex -interaction=nonstopmode main.tex

echo.
echo [SUCCESS] Build complete! Output: main.pdf
goto end

:clean
echo [CLEAN] Removing build artifacts...
del /q *.aux *.bbl *.blg *.fdb_latexmk *.fls *.log *.out *.toc *.lof *.lot *.synctex.gz *.nav *.snm *.vrb *.bcf *.run.xml 2>nul
for /d %%d in (chapters) do (
    del /q "%%d\*.aux" 2>nul
)
echo [SUCCESS] Clean complete!

:end
