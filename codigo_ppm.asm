.data
    NUM_FRAMES:      .word 400
    WIDTH:           .word 640
    HEIGHT:          .word 360
    
    HALF_HEIGHT:       .word 180
    HALF_TOTAL_PIXELS: .word 115200
    HALF_IMG_BYTES:    .word 345600
    HALF_ACCUM_BYTES:  .word 1382400

    FILENAME_PREFIX: .asciiz "frame_"
    FILENAME_SUFFIX: .asciiz ".ppm"
    OUTPUT_FILENAME: .asciiz "background.ppm"
    PGM_HEADER:      .asciiz "P6\n640 360\n255\n"
    MSG_START:       .asciiz "Iniciando calculo (processamento em 2 metades)\n"
    MSG_HALF1:       .asciiz "Processando a metade SUPERIOR da imagem\n"
    MSG_HALF2:       .asciiz "Processando a metade INFERIOR da imagem\n"
    MSG_END:         .asciiz "Modelo de fundo gerado em 'background.ppm'.\n"
    MSG_ERROR_FILE:  .asciiz "\nErro: Nao foi possivel abrir o arquivo: "

    .align 2  # Garante alinhamento de 4 bytes para o próximo dado
    ptr_buffer_half_frame: .word 0
    ptr_buffer_half_accum: .word 0
    
    filename_buffer: .space 32
    char_buffer:     .space 1

.text
.globl main

# FUNÇÃO PRINCIPAL
main:
    # Gerenciamento da Pilha (Stack)
    addi $sp, $sp, -28
    sw $ra, 0($sp)
    sw $s0, 4($sp)                 # s0: contador de frames (k)
    sw $s1, 8($sp)                 # s1: total de frames
    sw $s2, 12($sp)                # s2: ponteiro para buffer da metade do frame
    sw $s3, 16($sp)                # s3: ponteiro para buffer acumulador da metade
    sw $s4, 20($sp)                # s4: descritor do arquivo de SAÍDA
    sw $s5, 24($sp)                # s5: total de pixels na metade

    li $v0, 4
    la $a0, MSG_START
    syscall

    # ALOCAÇÃO DINÂMICA DE MEMÓRIA (HEAP)
    # Para evitar os limites de memória estática do MARS, solicitamos memória dinâmica (heap) em tempo de execução usando a syscall 9 (sbrk).
    li $v0, 9                      # Código da syscall 9 para alocar memória
    lw $a0, HALF_IMG_BYTES         # Carrega o tamanho do buffer do frame
    syscall                        # Aloca a memória; $v0 contém o ponteiro
    sw $v0, ptr_buffer_half_frame  # Salva o ponteiro para uso futuro

    li $v0, 9
    lw $a0, HALF_ACCUM_BYTES
    syscall
    sw $v0, ptr_buffer_half_accum

    # Abre o arquivo de saída e escreve o cabeçalho
    li $v0, 13
    la $a0, OUTPUT_FILENAME
    li $a1, 1
    syscall
    move $s4, $v0       # Salva o descritor do arquivo de saída em $s4
    
    li $v0, 15
    move $a0, $s4
    la $a1, PGM_HEADER
    li $a2, 15
    syscall

    # Carrega ponteiros e constantes para uso geral
    lw $s2, ptr_buffer_half_frame
    lw $s3, ptr_buffer_half_accum
    lw $s5, HALF_TOTAL_PIXELS
    
    # ETAPA 1: PROCESSA A PRIMEIRA METADE (SUPERIOR)
    li $v0, 4
    la $a0, MSG_HALF1
    syscall
    
    jal zerar_acumulador           # Zera o buffer que irá guardar a soma

    # Loop principal sobre os frames de entrada
    li $s0, 1                      # Inicia o contador de frames em 1
    lw $s1, NUM_FRAMES             # Carrega o total de frames
    
loop_metade1:
    bgt $s0, $s1, fim_loop_metade1 # Se o contador for maior que o total, encerra
    
    move $a0, $s0
    jal montar_nome_arquivo        # Cria o nome do arquivo, ex: "frame_0001.ppm"
    
    la $a0, filename_buffer
    jal ler_primeira_metade        # Abre, pula cabeçalho e lê a primeira metade do frame
    
    jal somar_no_acumulador        # Soma os pixels lidos no buffer acumulador

    addi $s0, $s0, 1               # Incrementa o contador de frames
    j loop_metade1
    
fim_loop_metade1:

    jal calcular_e_escrever_media  # Calcula a média da metade e escreve no arquivo.

    # ETAPA 2: PROCESSA A SEGUNDA METADE (INFERIOR)
    li $v0, 4
    la $a0, MSG_HALF2
    syscall
    
    jal zerar_acumulador           # Zera o buffer acumulador novamente
    
    # Loop principal sobre os frames de entrada
    li $s0, 1
    
loop_metade2:
    bgt $s0, $s1, fim_loop_metade2
    
    move $a0, $s0
    jal montar_nome_arquivo

    la $a0, filename_buffer
    jal ler_segunda_metade         # Abre, pula cabeçalho, PULA a 1ª metade e LÊ a 2ª
    
    jal somar_no_acumulador

    addi $s0, $s0, 1
    j loop_metade2
    
fim_loop_metade2:
    
    jal calcular_e_escrever_media

    li $v0, 16                     # Fecha o arquivo de saída
    move $a0, $s4
    syscall
    
    li $v0, 4
    la $a0, MSG_END
    syscall
    
    # Restaura registradores e libera a pilha
    lw $ra, 0($sp)
    lw $s0, 4($sp) 
    lw $s1, 8($sp) 
    lw $s2, 12($sp)
    lw $s3, 16($sp) 
    lw $s4, 20($sp)
    lw $s5, 24($sp)
    addi $sp, $sp, 28
    
    li $v0, 10
    syscall

# FUNÇÃO: zerar_acumulador - preenche o buffer acumulador com zeros
zerar_acumulador:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    lw $t0, HALF_ACCUM_BYTES       # Carrega o tamanho do buffer
    li $t1, 0                      # Inicia o contador de bytes em 0
    lw $t2, ptr_buffer_half_accum  # Carrega o ponteiro base do buffer
    
loop_zerar:
    bge $t1, $t0, fim_loop_zerar   # Se o contador atingir o tamanho, encerra
    sb $zero, 0($t2)               # Escreve um byte zero
    addi $t2, $t2, 1               # Avança o ponteiro
    addi $t1, $t1, 1               # Incrementa o contador
    j loop_zerar
    
fim_loop_zerar:
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

# FUNÇÃO: ler_primeira_metade - abre um frame, pula o cabeçalho e lê a primeira metade dos dados
ler_primeira_metade:
    addi $sp, $sp, -8
    sw $ra, 0($sp)
    sw $s7, 4($sp)      # Salva $s7 para usar como descritor do frame
    
    li $v0, 13          # Syscall para abrir arquivo
    li $a1, 0           # Modo de leitura
    syscall
    blt $v0, $zero, erro_arquivo
    move $s7, $v0
    
    jal pular_cabecalho # Chama a sub-rotina que pula o cabeçalho do PPM

    li $v0, 14
    move $a0, $s7
    lw $a1, ptr_buffer_half_frame
    lw $a2, HALF_IMG_BYTES
    syscall             # Lê a primeira metade dos pixels
    
    li $v0, 16
    move $a0, $s7
    syscall             # Fecha o arquivo
    
    lw $ra, 0($sp)
    lw $s7, 4($sp)
    addi $sp, $sp, 8
    jr $ra

# FUNÇÃO: ler_segunda_metade - abre um frame, pula o cabeçalho, descarta a primeira metade e lê a segunda
ler_segunda_metade:
    addi $sp, $sp, -8
    sw $ra, 0($sp)
    sw $s7, 4($sp)
    
    li $v0, 13
    li $a1, 0
    syscall
    blt $v0, $zero, erro_arquivo
    move $s7, $v0
    
    jal pular_cabecalho

    # Pula a primeira metade lendo para o buffer, mas sem usar os dados
    li $v0, 14
    move $a0, $s7
    lw $a1, ptr_buffer_half_frame
    lw $a2, HALF_IMG_BYTES
    syscall
    
    # Lê a segunda metade, que agora é a próxima no arquivo
    li $v0, 14
    move $a0, $s7
    lw $a1, ptr_buffer_half_frame
    lw $a2, HALF_IMG_BYTES
    syscall

    li $v0, 16
    move $a0, $s7
    syscall
    
    lw $ra, 0($sp)
    lw $s7, 4($sp)
    addi $sp, $sp, 8
    jr $ra

# FUNÇÃO: pular_cabecalho (auxiliar) - lê um arquivo byte a byte até encontrar 3 newlines
pular_cabecalho:
    # O descritor do arquivo a ser lido deve estar em $s7
    li $t1, 0                      # Zera o contador de newlines
    
loop_pular:
    li $v0, 14
    move $a0, $s7
    la $a1, char_buffer
    li $a2, 1
    syscall
    
    lb $t2, char_buffer            # Carrega o byte lido
    bne $t2, 10, loop_pular        # Se não for '\n' (10), continua
    
    addi $t1, $t1, 1               # Se for '\n', incrementa o contador
    blt $t1, 3, loop_pular         # Se encontrou menos de 3, continua
   
    jr $ra

# FUNÇÃO: somar_no_acumulador - itera sobre os pixels da metade lida e soma cada canal (RGB) no buffer acumulador
somar_no_acumulador:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    li $t1, 0              # Inicia o contador de pixels (p = 0)
    
loop_soma:
    bge $t1, $s5, fim_loop_soma    # Se (p >= total de pixels da metade), encerra
    mul $t2, $t1, 3                # Offset de byte para o buffer de frame (p * 3)
    mul $t3, $t1, 12               # Offset de byte para o buffer acumulador (p * 12)
    
    # Processa canal Vermelho (R)
    add $t4, $s2, $t2              # Endereço do pixel R no buffer de frame
    lbu $t6, 0($t4)                # Carrega o valor do byte R
    add $t5, $s3, $t3              # Endereço da soma de R no acumulador
    lw $t7, 0($t5)                 # Carrega o valor da soma atual
    add $t7, $t7, $t6              # Soma o novo valor
    sw $t7, 0($t5)                 # Salva a nova soma
    
    # Processa canal Verde (G)
    addi $t4, $t4, 1               # Avança para o byte G no buffer de frame
    lbu $t6, 0($t4)
    addi $t5, $t5, 4               # Avança para a word de soma G no acumulador
    lw $t7, 0($t5)
    add $t7, $t7, $t6
    sw $t7, 0($t5)

    # Processa canal Azul (B)
    addi $t4, $t4, 1               # Avança para o byte B no buffer de frame
    lbu $t6, 0($t4)
    addi $t5, $t5, 4               # Avança para a word de soma B no acumulador
    lw $t7, 0($t5)
    add $t7, $t7, $t6
    sw $t7, 0($t5)
    
    addi $t1, $t1, 1               # p++
    j loop_soma
    
fim_loop_soma:
    lw $ra, 0($sp) 
    addi $sp, $sp, 4 
    jr $ra

# FUNÇÃO: calcular_e_escrever_media - calcula a média para cada pixel da metade acumulada e escreve o resultado diretamente no arquivo de saída
calcular_e_escrever_media:
    addi $sp, $sp, -4 
    sw $ra, 0($sp)
    lw $t1, NUM_FRAMES             # Carrega o divisor
    li $t2, 0              	   # Inicia o contador de pixels (p = 0)
            
loop_media:
    bge $t2, $s5, fim_loop_media
    mul $t3, $t2, 12               # Offset do acumulador
    mul $t4, $t2, 3                # Offset do buffer de resultado (reutilizando o buffer de frame)
    
    # Calcula e armazena a média para o canal Vermelho (R)
    add $t5, $s3, $t3
    lw $t6, 0($t5)
    div $t6, $t1
    mflo $t6
    add $t7, $s2, $t4
    sb $t6, 0($t7)

    # Calcula e armazena a média para o canal Verde (G)
    addi $t5, $t5, 4
    lw $t6, 0($t5)
    div $t6, $t1
    mflo $t6
    addi $t7, $t7, 1
    sb $t6, 0($t7)
    
    # Calcula e armazena a média para o canal Azul (B)
    addi $t5, $t5, 4
    lw $t6, 0($t5)
    div $t6, $t1
    mflo $t6
    addi $t7, $t7, 1
    sb $t6, 0($t7)
    
    addi $t2, $t2, 1
    j loop_media
    
fim_loop_media:
    # Escreve o buffer de resultado (a metade processada) no arquivo de saída
    li $v0, 15
    move $a0, $s4
    lw $a1, ptr_buffer_half_frame
    lw $a2, HALF_IMG_BYTES
    syscall

    lw $ra, 0($sp) 
    addi $sp, $sp, 4 
    jr $ra
    
# FUNÇÃO: montar_nome_arquivo - constrói o nome de um arquivo (ex: "frame_0010.pgm")
montar_nome_arquivo:
    addi $sp, $sp, -4              # Aloca espaço na pilha
    sw $ra, 0($sp)                 # Salva o endereço de retorno

    # Copia o prefixo "frame_" para o buffer 
    la $t0, filename_buffer        # Carrega o endereço do buffer de destino
    la $t1, FILENAME_PREFIX        # Carrega o endereço da string de prefixo
    
loop_copia_prefixo:
    lb $t2, 0($t1)                 # Carrega um byte do prefixo
    sb $t2, 0($t0)                 # Armazena o byte no buffer de destino
    beq $t2, $zero, fim_loop_copia_prefixo # Se for o fim da string, termina
    addi $t0, $t0, 1               # Avança o ponteiro de destino
    addi $t1, $t1, 1               # Avança o ponteiro de origem
    j loop_copia_prefixo
    
fim_loop_copia_prefixo:
    addi $t0, $t0, -1              # Recua o ponteiro para sobrescrever o terminador nulo

    # Converte o número do frame para uma string de 4 dígitos
    move $t1, $a0                  # Copia o número do frame para $t1
    
    # Isola e armazena o dígito de milhares
    li $t2, 1000                   # Define o divisor
    div $t3, $t1, $t2              # Isola o dígito
    addi $t3, $t3, 48              # Converte para caractere ASCII
    sb $t3, 0($t0)                 # Armazena no buffer
    rem $t1, $t1, $t2              # Pega o resto da divisão para o próximo passo
    addi $t0, $t0, 1               # Avança o ponteiro do buffer

    # Isola e armazena o dígito de centenas
    li $t2, 100
    div $t3, $t1, $t2
    addi $t3, $t3, 48
    sb $t3, 0($t0)
    rem $t1, $t1, $t2
    addi $t0, $t0, 1

    # Isola e armazena o dígito de dezenas
    li $t2, 10
    div $t3, $t1, $t2
    addi $t3, $t3, 48
    sb $t3, 0($t0)
    rem $t1, $t1, $t2
    addi $t0, $t0, 1

    # O resto final é o dígito das unidades
    addi $t3, $t1, 48
    sb $t3, 0($t0)
    addi $t0, $t0, 1

    # Anexa o sufixo ".pgm"
    la $t1, FILENAME_SUFFIX
    
loop_copia_sufixo:
    lb $t2, 0($t1)
    sb $t2, 0($t0)
    beq $t2, $zero, fim_loop_copia_sufixo
    addi $t0, $t0, 1
    addi $t1, $t1, 1
    j loop_copia_sufixo
    
fim_loop_copia_sufixo:
    lw $ra, 0($sp)                 # Restaura o endereço de retorno
    addi $sp, $sp, 4               # Libera o espaço na pilha
    jr $ra                         # Retorna para a função chamadora

# FUNÇÃO: erro_arquivo
erro_arquivo:
    # Imprime a mensagem de erro padrão
    li $v0, 4
    la $a0, MSG_ERROR_FILE
    syscall
    
    # Imprime o nome do arquivo que falhou
    li $v0, 4
    la $a0, filename_buffer
    syscall
    
    # Encerra o programa
    li $v0, 10
    syscall