# p2pchat

In diesem Projekt versuchten wir einen P2P Chat zu implementieren.

Das Projekt besteht aus 2 Teilen: 
1) Ein P2P-Chat 
2) Ein Broadcasting anhand eines Tokenring

Wie führt man die Implementierung des Chat's (1) aus:

1) Compiliere alle Files
2) ip.sh Permission zur Ausführung erteilen
3) Erstelle ein File: Contact.txt
4) Dupliziere den gesamten Ordner
5) Im Ordner wo sich die .erl-Files befinden ein Terminal starten
6) ./ip.sh ausführen
7) Benutername schreiben
8) 'user@IP-Adresse' kopieren und in den anderen Ordner im Contact.txt beifügen
    nach dem Kopieren, speichern nicht vergessen!
  Beispiel:
      Ordner 1: 
        nach Ausführung von ./ip.sh: user1@111.111.22.22
      Ordner 2:
        nach Ausführung von ./ip.sh: user2@111.111.22.22
     
    user1@111.111.22.22 ins Contact.txt in Ordner 2 kopieren
    user2@111.111.22.22 ins Contact.txt in Ordner 1 kopieren
     
9) Im Erlang-Shell: p2p:start().
