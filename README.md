# Cálculo de Modelo de Fundo em Assembly MIPS-32

![Linguagem](https://img.shields.io/badge/Linguagem-MIPS%20Assembly-blue)
![Plataforma](https://img.shields.io/badge/Plataforma-MARS%204.5-red)

Implementação de um algoritmo de **Modelo de Fundo** (*Background Modeling*) através da média aritmética de quadros de vídeo, desenvolvido inteiramente em Assembly para a arquitetura MIPS-32. Este projeto foi realizado para a disciplina de Organização e Arquitetura de Computadores.

O objetivo principal é demonstrar a manipulação de arquivos e o processamento de dados em baixo nível, aplicando um algoritmo clássico de visão computacional.

[Veja o relátorio completo do projeto aqui](https://www.overleaf.com/read/ccrmdnwmknyb#f7e7d1)

---

## Sobre o Projeto

O modelo de fundo é uma técnica utilizada para separar objetos em movimento (primeiro plano) de um cenário estático (fundo). Este programa implementa o método da média, onde o valor de cada pixel na imagem de fundo é a média dos valores dos pixels correspondentes em uma longa sequência de imagens (frames).

O projeto contém duas implementações principais:
1.  **`codigo_pgm.asm`**: A implementação base, que processa imagens em escala de cinza no formato **PGM (P5)**.
2.  **`codigo_ppm.asm`**: A implementação avançada (Ponto Extra), que processa imagens coloridas no formato **PPM (P6)** e contorna limitações de memória do simulador.

## Funcionalidades

1. **Cálculo de Modelo de Fundo** por Média Aritmética de Frames.
2. **Suporte para Imagens PGM (P5)**: Processamento em escala de cinza.
3. **Suporte para Imagens PPM (P6)**: Processamento colorido (RGB), tratando cada canal de cor de forma independente.
4. **Solução de Contorno de Limites**: A versão PPM implementa uma estratégia de processamento em duas metades para operar dentro das restrições de memória do simulador MARS.

## Como Executar

Para executar este projeto, você precisará do Java e do simulador MARS.

### Pré-requisitos

- **Java Development Kit (JDK)**: Necessário para rodar o simulador.
- **MARS (MIPS Assembler and Runtime Simulator)**: O ambiente de simulação para o código MIPS. [Faça o download aqui](https://github.com/dpetersanderson/MARS/).

### Instruções

1.  Clone este repositório:
    ```bash
    git clone [URL_DO_SEU_REPOSITORIO]
    ```
2.  Coloque os seus arquivos de imagem (frames) na pasta raiz do projeto. Os arquivos devem seguir o padrão de nomenclatura `frameXXXX.pgm` ou `frameXXXX.ppm` (com 4 dígitos).
3.  Inicie o simulador MARS.
4.  Abra (`File > Open`) o arquivo `.asm` que deseja executar (`codigo_pgm.asm` ou `codigo_ppm.asm`).
5.  Compile o código clicando em **Assemble** (ou F3).
6.  Execute o programa clicando em **Go** (ou F5).
7.  Após a execução, um arquivo de saída (`background.pgm` ou `background.ppm`) será gerado na mesma pasta.

## Detalhes da Implementação

A maior complexidade do projeto foi o gerenciamento de memória em baixo nível, especialmente na transição do formato PGM para o PPM.

### Versão PGM

A implementação para PGM (escala de cinza) utiliza buffers estáticos para armazenar os dados de um frame e a soma acumulada dos pixels. A lógica é direta: para cada pixel, o valor do byte é somado a um acumulador (do tipo `word` para evitar overflow) e, ao final, a média é calculada.

### Versão PPM 

A adaptação para imagens coloridas (PPM) triplicou a necessidade de memória, pois cada pixel agora possui 3 canais de cor (RGB). Isso tornou inviável o uso de buffers estáticos devido aos limites do MARS. A solução inicial foi usar **alocação dinâmica de memória** (`heap`) com a *syscall 9 (sbrk)*.

No entanto, mesmo com alocação dinâmica, o simulador MARS apresentou um limite máximo por alocação, impedindo que um frame colorido inteiro fosse carregado na memória de uma só vez. Para superar este desafio, foi implementada uma estratégia de **processamento em duas metades**:

1.  O programa aloca buffers para apenas metade da altura da imagem.
2.  Ele itera sobre todos os frames de entrada, processando e acumulando os dados apenas da **metade superior** da imagem.
3.  A média da metade superior é calculada e escrita no arquivo de saída.
4.  O processo é repetido do zero para a **metade inferior**, onde o programa abre cada frame novamente, descarta a primeira metade dos dados e lê/processa apenas a segunda metade.

Essa abordagem representa um balanço ideal entre o uso de memória e a performance, permitindo que o algoritmo seja executado dentro das restrições do ambiente.

## Resultados

A eficácia do algoritmo pode ser observada comparando uma imagem de entrada com o modelo de fundo gerado.

**Exemplo PGM (Escala de Cinza):**

| Frame de Entrada | Modelo de Fundo Gerado |
| :--------------: | :--------------------: |
| ![Frame PGM de Entrada](frame0001_cinza.png) | ![Fundo PGM Gerado](modelofundo_cinza.png) |
| *Um único quadro da sequência.* | *Resultado após processar 400 frames.* |

**Exemplo PPM (Colorido):**

| Frame de Entrada | Modelo de Fundo Gerado |
| :--------------: | :--------------------: |
| ![Frame PPM de Entrada](frame0001_colorido.png) | ![Fundo PPM Gerado](modelofundo_colorido.png) |
| *Um único quadro colorido.* | *Resultado após processar 400 frames em duas metades.* |
