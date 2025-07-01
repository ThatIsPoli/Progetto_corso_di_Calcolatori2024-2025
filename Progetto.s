.data
#ACCESSLIST: ID tessera (2 bytes),livello (1 byte),tentativoDiErrore (1 byte)
ACCESSLIST: .word 0x000A0300        #ID tessera 000A, 03 (livello 3), errori 00
            .word 0x000B0203        #ID tessera 000B, 02 (livello 2), errori 03
            .word 0x000C0400        #ID tessera 000C, 04 (livello 4), errori 00
            .word 0x000D0005        #ID tessera 000D, 00 (livello 0), errori 05
            .word 0x000E0304        #ID tessera 000E, 03 (livello 3), errori 04
            .word 0x00000000        #fine lista
 

#DOOR: ID porta (2 bytes), livello (2 bytes)
DOOR:   .word 0x00010002    #ID porta 0001 (1), 0002 (livello 2)
        .word 0x00020004    #ID porta 0002 (2), 0004 (livello 4)
        .word 0x00000000    #fine lista


#READCARD: ID tessera (2 bytes), ID porta (2 bytes)
READCARD:   .word 0x000A0001    #ID tessera 000A, ID porta 0001    ok(3>=2)
            .word 0x000C0002    #ID tessera 000C, ID porta 0002    ok(4>=4)  
            .word 0x000F0002    #ID tessera 000E, ID porta 0002    no(\>=4) #tesseraNonPresente
            .word 0x000D0001    #ID tessera 000D, ID porta 0001    no(0>=2) #tesseraBloccata
            .word 0x000B0002    #ID tessera 000B, ID porta 0002    no(2>=4) #tesseraLivelloTroppoBasso
            .word 0x000E0002    #ID tessera 000E, ID porta 0002    no(3>=4) #tesseraLivelloTroppoBasso e blocata poi
            .word 0x00000000    #fine lista

COMMAND:    .word 0x00000000    #output di command.
#schema ultimo byte  di command: ( porta aperta | tessera non presente in ACCESSLIST | porta NON aperta | Errori>4 )
START:      .word 0x00000006    #valore di partenza per ogni command  (ultimo byte: 0000 0110)  , serve per il reset ogni volta che parte il ciclo      
                                                                
                                                                
#aspettativa COMMAND nella seguente configurazione:
#1: 1000
#2: 1000
#3: 0110
#4: 0011
#5: 0010
#6: 0011




.text
.globl main


main:   la $s5, READCARD        #caricamento READCARD
        lw $t0, 0($s5)          #carico in $t0 la word di $s5 (READCARD)

        la $t9, START           #carica l'indirizzo di START
        lw $s1, 0($t9)          #carica il contenuto di START

        

ciclo:  #caricamento delle liste e di COMMAND
        la $s3, ACCESSLIST
        la $s4, DOOR
        
        la $s6, COMMAND
            

        
        
        #config di COMMAND
        lw  $s0, 0($s6)          #carico in $s0 il byte di $s6 (COMMAND)

        #reset di $s0 in configurazione base per scrivere command (0110)
        add $s0, $zero,$s1         
        andi $s0, $s0, 0xFF      #tiene solo l’ultimo byte (quello che rappresenta command)

        

        #-------- ora scorro le varie liste e verifico gli incroci --------
        
        lw  $t3, 0($s3)          #carico in $t3 la word di $s3 (ACCESSLIST)

loopAL: #verifico scorrendo ACCESSLIST
        


        #formattazione di $t3 per ID (ACCESSLIST)
        srl $t4, $t3, 16         #shift logico dx (davanti ho zero) di 16 bit=4 cifre Hex
        
        #formattazione di $t0 per ID ->in $t5 (READCARD)
        srl $t5, $t0, 16        #shift logico dx (davanti ho zero) di 16 bit=4 cifre Hex
                 
        beq $t5, $t4, flagAL    #se c'è corrispondenza agisce su command e mette secondo bit a 0

        addi $s3, $s3, 4        #incrementa puntatore di ACCESSLIST
        lw $t3, 0($s3)          #carico in $t3 la nuova word di $s3 (ACCESSLIST)
        bne $t3, $zero, loopAL  #jump a loopAL se $t3 (la next word di ACCESSLIST) != $zero (word di finelista)

        jr CaricaCommand        #carica command perchè lista finita


               
loopDOOR:       #verifico scorrendo DOOR
                lw  $t3, 0($s4)                         #carico in $t3 la word di $s4 (DOOR)
                beq $t3, $zero, CaricaCommand           #jump a CaricaCommand se $t3 (word di DOOR) == $zero (word di finelista), ovvero lista DOOR finita

                #formattazione id porta di DOOR
                srl $t1, $t3, 16                        #shift logico dx (davanti ho zero) di 16 bit=4 cifre Hex

                #formattazione id porta di READCARD
                andi $t4, $t0, 0xFFFF               #andi per prelevare solo id porta

                #verifica id porta (se READCARD combacia con porta allora FlagDoor)
                beq $t1, $t4, FlagDoor 

                
                addi $s4, $s4, 4                        #incrementa puntatore di DOOR

                jr loopDOOR          


IncrementaErrore:       andi $t7, $t8, 0x00FF   #estrai errori dalla tessera t8 in t7

                        slti $t4, $t7, 254
                        beq $t4, $zero, Continua        #se gli errori della tessera (salvati in t7) sono maggiori di 254 allora Continua direttamente perhcè senno si sfora in zone di non competenza del byte errori della tessera

                        addi $t7, $t7,1         #errori=errori+1

                        #ricava parte sx senza errori
                        srl $t9, $t8, 8               #shift a dx di 8 bit
                        sll $t9, $t9, 8               #shift a sx di 8 bit (...xx 0000 0000)

                        #ricostruisco la tessera con l'errore in piu in t8
                        or $t8, $t9, $t7

                        # Salva valore aggiornato in ACCESSLIST
                        sw $t8, 0($s2)

                        jr CaricaCommand



SetErroreCommand:       #set del bit relativo agli errori in command
                        addi $t9, $zero, 1
                        and $t7, $s0, $t9       #estrai bit errori da COMMAND
                        beq $t7, $t9, Continua  #se il bit errori di command è già settato a 1, Continua

                        ori $s0, $s0, 0x01      #set bit 4 ad 1 
                        andi $s0, $s0, 0xFF

                        #settaggio lvl tessera a 0000 0000
                        lui $t9, 0xFFFF         #carica 0xFFFF0000 in $t9
                        ori $t9, $t9, 0x00FF    #ora $t9 = 0xFFFF00FF
                        and $t8, $t8, $t9       #impostato lvl tessera a 0
                        
                        jr Continua
                 

CaricaCommand:  #verifica che il numero di errori sia minore di 5
                andi $t7, $t8, 0x00FF      #estrai errori da tessera
                slti $t4, $t7, 5
                bne $t4, $zero, Continua   #se errori < 5 , vai pure a salvare

                #se errori >= 5, la tessera è bloccata da ora in poi
                j SetErroreCommand
                
Continua:       #caricamento di COMMAND
                andi $s0, $s0, 0xFF
                sw $s0, COMMAND 

                #caricamento della tessera aggiornata (sovrascritta)
                sw $t8, 0($s2)     #da t8= tessera in s2 che è il puntatore SALVATO IN QUELLA SPECIFICA POSIZIONE

                #incrementa puntatore di READCARD per il prossimo ciclo
                addi $s5, $s5, 4     
                lw  $t0, 0($s5)         #carico in $t0 la nuova word di $s5 (READCARD)

                jr wait
        


#conta il tempo di wait
wait:   addi $t3, $t3, 1        #4 cicli      
        slt $t4, $t3, 4550000   #4 cicli ,4 550 000 operazioni perchè 50 000 000 / 11= 4 550 000  
        bne $t4, $zero, wait    #3 cicli
        
        
        and $t3, $t3, $zero     #rende disponibile $t3 per qualsiasi altro utilizzo
        jr stampaCommand
        



flagAL:  
        andi $s0, $s0, 0xFB             #bit 2=0, tessera presente

        move $t8, $t3                   #salva word tessera trovata in t8 perchè t3 viene sempre aggiornato
        move $s2, $s3                   #salva indirizzo tessera per update errori
        
        andi $t7, $t8, 0x00FF           #estrai errori
        slti $t9, $t7, 5                #verifica se errori < 5
        beq $t9, $zero, CaricaCommand   #se bloccata, carica command (skip)

        andi $t5, $t8, 0xFF00           #estrai livello
        srl  $t5, $t5, 8                #shift a dx di 8 bit = 1 byte per allinearlo

        andi $s0, $s0, 0xFB             #modifica COMMAND ultimo byte (0000 0110 → 0000 0010)
        andi $s0, $s0, 0xFF

        jr  loopDOOR




FlagDoor:       #formattazione lvl porta (lvl tessera c'è gia= $t5)
                andi $t4, $t3, 0xFFFF   #andi per prelevare solo lvl porta

                #verifico corrispondenza(se lvlTessera < lvl PORTA allora IncrementaErrore )
                slt $t6, $t5, $t4 
                bne $t6, $zero, IncrementaErrore 

                #imposto command come aperta (setto gli 1 e gli zeri (ignoro X) cosi: 1x0x)
                andi $s0, $s0, 0xFD     #reset bit 3 a 0
                andi $s0, $s0, 0xFF

                ori $s0, $s0, 0x08      #set bit 1 ad 1
                andi $s0, $s0, 0xFF


                jr CaricaCommand


stampaCommand:  li $t6, 3                       #contatore da 3 a 0 (bit 3, 2, 1, 0)

dividiStringa:  srlv $t7, $s0, $t6              #shift a destra di t6 posizioni (variable)
                andi $a0, $t7, 0x1              #ricavo il singolo bit
                addi $a0, $a0, 48               #sommo al bit + 48 perchè in ASCII 48=0 e 49=1
                li $v0, 11                      #syscall print char
                syscall                         #stampa effettiva bit

                addi $t6, $t6, -1
                slt $t2, $t6, $zero
                beq $t2, $zero, dividiStringa   #finché t6 >= 0 vai a dividiStringa

                li $a0, 10                      #print("\n"), 10="\n" in ASCII              
                syscall                         #stampa effettiva "\n"

                beq $t0, $zero, end             #verifica se è finita READCARD ed in tal caso end
                jr ciclo


end:    jr  $ra  


        

