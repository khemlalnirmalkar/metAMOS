#!python

import os, sys, string, time, BaseHTTPServer, getopt, re, subprocess, webbrowser
from operator import itemgetter

from utils import *
from findorfs import FindORFS

sys.path.append(INITIAL_UTILS)
from ruffus import *

_readlibs = []
_skipsteps = []
_settings = Settings()

def init(reads, skipsteps):
   global _readlibs
   global _skipsteps

   _readlibs = reads
   _skipsteps = skipsteps

def parse_metaphyler(giMapping, toTranslate, output):
   giDictionary = {};
   try:
      GIs = open(giMapping, 'r')
   except IOError as e:
      return
   for line in GIs:
      line = line.replace("\n","")
      splitLine = line.split("\t")
      giDictionary[splitLine[0]] = splitLine[1]
   GIs.close();
   try:
      GIs = open(toTranslate, 'r')
   except IOError as e:
      print "Exception opening file %s"%(e)
      return
   outf = open(output, 'w')
   for line in GIs:
      line = line.replace("\n","")
      splitLine = line.split("\t")
      if splitLine[1] in giDictionary:
         outf.write(line.replace(splitLine[1], giDictionary[splitLine[1]]) + "\n")
   GIs.close()
   outf.close()

@follows(FindORFS)
@files("%s/Assemble/out/%s.asm.contig"%(_settings.rundir,_settings.PREFIX),"%s/Abundance/out/%s.taxprof.pct.txt"%(_settings.rundir,_settings.PREFIX))
def Abundance(input,output):
   if "FindORFS" in _skipsteps or "Abundance" in _skipsteps:
      return 0

   #run_process(_settings, "unlink %s/Abundance/in/%s.gene.cvg"%(_settings.rundir,_settings.PREFIX),"Abundance")
   #run_process(_settings, "unlink %s/Abundance/in/%s.faa"%(_settings.rundir,_settings.PREFIX),"Abundance")
   #run_process(_settings, "ln -t %s/Abundance/in/ -s %s/FindORFS/out/%s.faa"%(_settings.rundir,_settings.rundir,_settings.PREFIX),"Abundance")
   #run_process(_settings, "ln -t %s/Abundance/in/ -s %s/FindORFS/out/%s.gene.cvg"%(_settings.rundir,_settings.rundir,_settings.PREFIX),"Abundance")
   blastfile = _settings.PREFIX+".blastx"
   blastc = _settings.BLAST + os.sep + "blastall"
   formatc = _settings.BLAST + os.sep + "formatdb"
   run_process(_settings, "%s  -p T -i %s/DB/markers.pfasta"%(formatc,_settings.METAMOS_UTILS),"Abundance")
   run_process(_settings, "%s -p blastp -i %s/FindORFS/out/%s.faa -d %s/DB/markers.pfasta -m8 -b10 -v10 -a %s -o %s/Abundance/out/%s.blastp"%(blastc, _settings.rundir,_settings.PREFIX,_settings.METAMOS_UTILS,_settings.threads,_settings.rundir,_settings.PREFIX),"Abundance")

   run_process(_settings, "perl %s/perl/metaphyler_contigs.pl %s/Abundance/out/%s.blastp %s %s/FindORFS/out/%s.gene.cvg %s/Abundance/out %s"%(_settings.METAMOS_UTILS,_settings.rundir,_settings.PREFIX,_settings.PREFIX,_settings.rundir,_settings.PREFIX,_settings.rundir,_settings.METAMOS_UTILS),"Abundance")

   # finally add the GI numbers to the results where we can
   parse_metaphyler("%s/DB/markers.toGI.txt"%(_settings.METAMOS_UTILS), "%s/Abundance/out/%s.blastp"%(_settings.rundir, _settings.PREFIX), "%s/Abundance/out/%s.gi.blastp"%(_settings.rundir, _settings.PREFIX))
   run_process(_settings, "cp %s/Abundance/out/%s.gi.blastp %s/Postprocess/in/%s.hits"%(_settings.rundir, _settings.PREFIX,_settings.rundir,_settings.PREFIX))
