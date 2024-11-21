#        UDPPortDataStreamer V 1.0  (UPDS)
#  (c) Jens Bongartz, 2024, RheinAhrCampus Remagen
#                Stand: 21.11.2024
#  ================================================
pkg load instrument-control;
clear all; clc;
# obj = dataStreamClass(name,plcolor,dt,plotwidth,plot,filter)
# createFilter(f_abtast,f_HP,f_NO,f_TP)
dataStream(1) = dataStreamClass("FBT","red",10,800,1,1); # externe Klasse
# createFilter(f_abtast,f_HP,f_NO,f_TP)
dataStream(1).createFilter(200,1,50,20);
#dataStream(1).peakDetector  = 1;
#dataStream(1).evalWindow    = 200;

#baudrate = 115200;
inputPort = udpPortClass();                   # externe Klasse
inputPort.createSelector(dataStream);         # >> inputPort.streamSelector
inputPort.createRegEx(dataStream);            # >> inputPort.regex_pattern

# Globale Variablen zur Programmsteuerung
global HP_filtered = 1 NO_filtered = 1 TP_filtered = 1 DQ_filtered = 0 DQ2_filtered = 0;
global quit_prg = 0 clear_data = 0 save_data = 0 rec_data = 1;

# Einstellwerte fuer die Programm-Performance [Sekunden]
Bench_Time      = 2;
#Plot_Time       = 0.1;
Plot_Time       = 0.1;          # Raspi: 0.025
#SerialPort_Time = 0.1;
SerialPort_Time = 0.025;          # Raspi: 0.025
Pause_Time      = 0.05;

# Der weitere Teil wird nur ausgefuehrt, wenn serielle Schnittstelle gefunden wurde
if !isempty(inputPort)
  # Graphikfenster initialisieren
  plotGraph = plotGraphClass(dataStream);       # externe Klasse
  cap = GUI_Elements(plotGraph.fi_1);           # externe Funktion
  displayInfo(plotGraph.fi_1);          clear inppu
        # externe Funktion
  inputPort.clearPort();                        # externe Klasse
  # Hauptschleife
  # =============
  datasetCounter = 0; datasetCounter_tic = 0; bytesReceived = 0;

  bench_tic = tic(); plot_tic = tic(); serial_tic = tic();
  [t_cpu_prev,t_user_prev,t_sys_prev] = cputime();

  do
    ## CLear-Button
    if (clear_data)
      j = 0;
      for i = 1:length(dataStream);
        dataStream(i).clear;
        if (dataStream(i).plot > 0)
          j = j + 1;
          set(plotGraph.subPl(j),"xlim",[0 dataStream(i).plotwidth*dataStream(i).dt]);
        endif
      endfor
      datasetCounter = 0;  datasetCounter_prev = 0;
      clear_data = 0;
    endif
    ## Save-Button
    if (save_data)

      rec_data = 0;
      dataMatrix = {};
      for i = 1:length(dataStream)
        dataMatrix{end+1} = dataStream(i).name;
        dataMatrix{end+1} = dataStream(i).array;
        dataMatrix{end+1} = dataStream(i).t;
      endfor
      myfilename = uiputf9ile();
      if (myfilename != 0)
        save("-text",myfilename,"dataMatrix");
      endif
      save_data = 0;
    endif

    # SerialPort auslesen
    # ==================
    s_toc = toc(serial_tic);
    if (s_toc > SerialPort_Time)
      [bytesAvailable,inChar] = inputPort.readPort();  # >> inputPort.inBuffer;
      bytesReceived = bytesReceived + bytesAvailable;
      if (rec_data)   # Wird vom REC-Button gesteuert
        countMatches = inputPort.parseInput(inChar,dataStream);
        datasetCounter = datasetCounter + countMatches;         # datasetCounter laeuft durch
        datasetCounter_tic = datasetCounter_tic + countMatches; # datasetCounter_tic >> Bench_Time
      endif
      serial_tic = tic();
    endif # s_toc

    # Plot-Graphikfenster
    # ===================
    p_toc = toc(plot_tic);
    if (p_toc > Plot_Time)
      plotGraph.draw(dataStream);
      if (ishandle(plotGraph.fi_1))
        set(cap(1),"string",num2str(datasetCounter));
      endif
      drawnow();
      plot_tic = tic();
    endif # p_toc
    # Entlastung der CPU
    pause(Pause_Time);

    # Benchmarking
    # ============
    b_toc = toc(bench_tic);
    if (b_toc > Bench_Time)
      # Empfangene Bytes pro Sekunde
      f_oct = round(datasetCounter_tic/b_toc);  datasetCounter_tic = 0;
      bytesPerSecond = round(bytesReceived / b_toc); bytesReceived = 0;

      [t_cpu,t_user,t_sys] = cputime();
      user_load = t_user - t_user_prev; sys_load = t_sys - t_sys_prev;
      t_cpu_prev = t_cpu; t_user_prev = t_user; t_sys_prev = t_sys;
      if (ishandle(plotGraph.fi_1))
        #set(cap(1),"string",num2str(datasetCounter));
        set(cap(2),"string",num2str(f_oct));
        set(cap(3),"string",num2str(b_toc));
        set(cap(4),"string",num2str(user_load));        # untere Wert
        #set(cap(7),"string",num2str(sys_load));        # obere Wert
        set(cap(5),"string",num2str(bytesPerSecond));
        set(cap(6),"string",num2str(countMatches));
      endif # ishandle(fi_1)
      bench_tic=tic();
    endif # b_toc
  until(quit_prg);
  clear inputPort.udp_01;
endif
clear all;
