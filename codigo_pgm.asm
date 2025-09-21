.data
    NUM_FRAMES:      .word 400
    WIDTH:           .word 640
    HEIGHT:          .word 360
    IMG_SIZE:        .word 230400

    FILENAME_PREFIX: .asciiz "frame_"
    FILENAME_SUFFIX: .asciiz ".pgm"
    OUTPUT_FILENAME: .asciiz "background.pgm"
    PGM_HEADER:      .asciiz "P5\n640 360\n255\n"

    MSG_START:       .asciiz "Iniciando o calculo do modelo de fundo...\n"
    MSG_PROCESSING:  .asciiz "Processando frame: "
    MSG_DONE:        .asciiz "\nCalculo da media finalizado.\n"
    MSG_WRITING:     .asciiz "Escrevendo arquivo de saida: background.pgm\n"
    MSG_COMPLETE:    .asciiz "Processo concluido com sucesso.\n"
    MSG_ERROR_FILE:  .asciiz "\nErro: Nao foi possivel abrir o arquivo: "
    NEWLINE:         .asciiz "\n"

    # Buffers de Memória
    .align 2  # Garante alinhamento de 4 bytes para o próximo dado.
    filename_buffer: .space 32
    frame_buffer:    .space 230400
    .align 2
    sum_buffer:      .space 921600
    result_buffer:   .space 230400
    char_buffer:     .space 1

.text
.globl main

# FUNÇÃO PRINCIPAL
main:
    # Início: Imprime mensagem inicial
    li $v0, 4
    la $a0, MSG_START
    syscall

    # Loop Principal: Processa cada frame
    li $s0, 1                      # Inicializa o contador de frames (i = 1)
    lw $s1, NUM_FRAMES             # Carrega o número total de frames em $s1

loop_frames:
    bgt $s0, $s1, end_loop_frames  # Se (contador > NUM_FRAMES), termina o loop

    # Monta o nome do arquivo para o frame atual
    move $a0, $s0                  # Passa o número do frame atual como argumento
    jal montar_nome_arquivo        # Chama a função para criar o nome do arquivo

    # Imprime qual frame está sendo processado
    li $v0, 4
    la $a0, MSG_PROCESSING
    syscall
    li $v0, 4
    la $a0, filename_buffer
    syscall
    li $v0, 4
    la $a0, NEWLINE
    syscall

    # Lê o arquivo PGM
    la $a0, filename_buffer        # Passa o endereço do nome do arquivo como argumento
    jal ler_pgm                    # Chama a função para ler o arquivo

    # Adiciona os dados do frame ao buffer de soma
    jal somar_frame_ao_acumulador  # Chama a função para somar os pixels

    # Fim da iteração
    addi $s0, $s0, 1               # Incrementa o contador de frames (i++)
    j loop_frames                  # Volta para o início do loop

end_loop_frames:
    # Calcula a média e grava o arquivo de saída
    li $v0, 4
    la $a0, MSG_DONE
    syscall
    jal calcular_media             # Chama a função para calcular a média

    li $v0, 4
    la $a0, MSG_WRITING
    syscall
    jal escrever_pgm               # Chama a função para gravar o arquivo final

    # Finalização do Programa
    li $v0, 4
    la $a0, MSG_COMPLETE
    syscall

    li $v0, 10                     # Código da syscall 10 para encerrar o programa.
    syscall

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
    li $t2, 1000                   # Divisor para o dígito de milhares
    div $t3, $t1, $t2              # Isola o dígito de milhares
    addi $t3, $t3, 48              # Converte para caractere ASCII
    sb $t3, 0($t0)                 # Armazena no buffer
    rem $t1, $t1, $t2              # Pega o resto da divisão
    addi $t0, $t0, 1               # Avança o ponteiro

    li $t2, 100                    # Divisor para o dígito de centenas
    div $t3, $t1, $t2
    addi $t3, $t3, 48
    sb $t3, 0($t0)
    rem $t1, $t1, $t2
    addi $t0, $t0, 1

    li $t2, 10                     # Divisor para o dígito de dezenas
    div $t3, $t1, $t2
    addi $t3, $t3, 48
    sb $t3, 0($t0)
    rem $t1, $t1, $t2
    addi $t0, $t0, 1

    addi $t3, $t1, 48              # O resto final é o dígito das unidades
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

# FUNÇÃO: ler_pgm - abre um arquivo PGM, pula o cabeçalho e lê os dados dos pixels
ler_pgm:
    addi $sp, $sp, -12             # Aloca espaço para 3 registradores na pilha
    sw $ra, 0($sp)                 # Salva o endereço de retorno
    sw $s0, 4($sp)                 # Salva $s0 para o descritor de arquivo
    sw $s1, 8($sp)                 # Salva $s1 para o contador de newlines

    # Abre o arquivo (modo leitura)
    li $v0, 13
    li $a1, 0
    syscall
    blt $v0, $zero, erro_arquivo   # Se houver erro ($v0 < 0), pula para a rotina de erro
    move $s0, $v0                  # Salva o descritor do arquivo em $s0

    # Pula o Cabeçalho PGM 
    li $s1, 0
    
loop_pular_cabecalho:
    li $v0, 14                     # Código da syscall para ler do arquivo
    move $a0, $s0                  # Passa o descritor do arquivo
    la $a1, char_buffer            # Buffer de destino de 1 byte
    li $a2, 1                      # Lê apenas 1 byte
    syscall
    lb $t0, char_buffer            # Carrega o byte lido
    li $t1, 10                     # Caractere de nova linha ('\n')
    bne $t0, $t1, loop_pular_cabecalho # Se não for newline, continua lendo
    addi $s1, $s1, 1               # Se for, incrementa o contador
    blt $s1, 3, loop_pular_cabecalho   # Se o contador for menor que 3, continua

    # Lê os dados dos pixels para o buffer_frame
    li $v0, 14
    move $a0, $s0
    la $a1, frame_buffer
    lw $a2, IMG_SIZE
    syscall

    # Fecha o arquivo
    li $v0, 16
    move $a0, $s0
    syscall

    # Restaura registradores e retorna
    lw $ra, 0($sp)
    lw $s0, 4($sp)
    lw $s1, 8($sp)
    addi $sp, $sp, 12
    jr $ra

# FUNÇÃO: erro_arquivo
erro_arquivo:
    li $v0, 4
    la $a0, MSG_ERROR_FILE
    syscall
    li $v0, 4
    la $a0, filename_buffer
    syscall
    li $v0, 10
    syscall

# FUNÇÃO: somar_frame_ao_acumulador
somar_frame_ao_acumulador:
    addi $sp, $sp, -20
    sw $ra, 0($sp)
    sw $s0, 4($sp)
    sw $s1, 8($sp)
    sw $s2, 12($sp)
    sw $s3, 16($sp)

    # Inicialização dos ponteiros e contadores
    la $s0, frame_buffer           # $s0 aponta para o buffer do frame atual (bytes)
    la $s1, sum_buffer             # $s1 aponta para o buffer de soma (words)
    lw $s2, IMG_SIZE               # $s2 guarda o número total de pixels
    li $s3, 0                      # $s3 é o contador do loop (i = 0)

loop_soma:
    bge $s3, $s2, fim_loop_soma    # Se (i >= total de pixels), termina

    # Carrega o valor do pixel do frame atual.
    add $t0, $s0, $s3              # Calcula o endereço: &frame_buffer[i]
    lbu $t1, 0($t0)                # Carrega o byte do pixel (unsigned)

    # Carrega o valor acumulado do buffer de soma
    sll $t2, $s3, 2                # Calcula o offset para words (i * 4)
    add $t3, $s1, $t2              # Calcula o endereço: &sum_buffer[i]
    lw $t4, 0($t3)                 # Carrega a soma acumulada (uma word)

    # Soma os valores e armazena de volta
    add $t5, $t4, $t1              # Nova soma = soma antiga + pixel atual
    sw $t5, 0($t3)                 # Armazena a nova soma no acumulador

    addi $s3, $s3, 1               # i++
    j loop_soma

fim_loop_soma:
    lw $ra, 0($sp)
    lw $s0, 4($sp)
    lw $s1, 8($sp)
    lw $s2, 12($sp)
    lw $s3, 16($sp)
    addi $sp, $sp, 20
    jr $ra

# FUNÇÃO: calcular_media
calcular_media:
    addi $sp, $sp, -24
    sw $ra, 0($sp)
    sw $s0, 4($sp)
    sw $s1, 8($sp)
    sw $s2, 12($sp)
    sw $s3, 16($sp)
    sw $s4, 20($sp)

    # Inicialização
    la $s0, sum_buffer             # $s0 aponta para o buffer de soma
    la $s1, result_buffer          # $s1 aponta para o buffer de resultado
    lw $s2, IMG_SIZE               # $s2 guarda o total de pixels
    lw $s3, NUM_FRAMES             # $s3 é o divisor (número de frames)
    li $s4, 0                      # $s4 é o contador do loop (i = 0)

loop_media:
    bge $s4, $s2, fim_loop_media   # Se (i >= total de pixels), termina

    # Carrega o valor da soma
    sll $t0, $s4, 2                # Calcula o offset para words (i * 4)
    add $t1, $s0, $t0              # Calcula o endereço: &sum_buffer[i]
    lw $t2, 0($t1)                 # Carrega o valor da soma do pixel i

    # Divide a soma pelo número de frames
    div $t2, $s3                   # Divide $t2 por $s3. O resultado (quociente) vai para o registrador LO
    mflo $t3                       # Move o resultado de LO para $t3

    # Armazena o resultado no buffer final
    add $t4, $s1, $s4              # Calcula o endereço: &result_buffer[i]
    sb $t3, 0($t4)                 # Armazena o byte da média no buffer de resultado

    addi $s4, $s4, 1               # i++.
    j loop_media

fim_loop_media:
    lw $ra, 0($sp)
    lw $s0, 4($sp)
    lw $s1, 8($sp)
    lw $s2, 12($sp)
    lw $s3, 16($sp)
    lw $s4, 20($sp)
    addi $sp, $sp, 24
    jr $ra

# FUNÇÃO: escrever_pgm
escrever_pgm:
    addi $sp, $sp, -8
    sw $ra, 0($sp)
    sw $s0, 4($sp)

    # Abre o arquivo (modo escrita)
    li $v0, 13
    la $a0, OUTPUT_FILENAME
    li $a1, 1                      # Flag 1 para modo de escrita
    syscall
    move $s0, $v0

    # Escreve o cabeçalho PGM
    li $v0, 15
    move $a0, $s0
    la $a1, PGM_HEADER
    li $a2, 15                     # Tamanho do cabeçalho PGM é 15 bytes
    syscall

    # Escreve os dados dos pixels do buffer de resultado
    li $v0, 15
    move $a0, $s0
    la $a1, result_buffer
    lw $a2, IMG_SIZE
    syscall

    # Fecha o arquivo
    li $v0, 16
    move $a0, $s0
    syscall

    lw $ra, 0($sp)
    lw $s0, 4($sp)
    addi $sp, $sp, 8
    jr $ra