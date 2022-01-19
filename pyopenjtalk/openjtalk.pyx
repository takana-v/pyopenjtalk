# coding: utf-8
# cython: boundscheck=True, wraparound=True
# cython: c_string_type=unicode, c_string_encoding=ascii

import numpy as np

cimport numpy as np
np.import_array()

cimport cython

from openjtalk.mecab cimport Mecab, Mecab_initialize, Mecab_load, Mecab_analysis
from openjtalk.mecab cimport Mecab_get_feature, Mecab_get_size, Mecab_refresh, Mecab_clear
from openjtalk.mecab cimport mecab_dict_index, createModel, Model, Tagger, Lattice
from openjtalk.njd cimport NJD, NJD_initialize, NJD_refresh, NJD_print, NJD_clear
from openjtalk cimport njd as _njd
from openjtalk.jpcommon cimport JPCommon, JPCommon_initialize,JPCommon_make_label
from openjtalk.jpcommon cimport JPCommon_get_label_size, JPCommon_get_label_feature
from openjtalk.jpcommon cimport JPCommon_refresh, JPCommon_clear
from openjtalk cimport njd2jpcommon
from openjtalk.text2mecab cimport text2mecab
from openjtalk.mecab2njd cimport mecab2njd
from openjtalk.njd2jpcommon cimport njd2jpcommon
from libc.string cimport strlen

cdef inline int Mecab_load_ex(Mecab *m, char* dicdir, char* userdic):
    if userdic == NULL or strlen(userdic) == 0:
        return Mecab_load(m, dicdir)

    if m == NULL or dicdir == NULL or strlen(dicdir) == 0:
        return 0

    Mecab_clear(m)

    cdef (char*)[5] argv = ["mecab", "-d", dicdir, "-u", userdic]
    cdef Model *model = createModel(5, argv)

    if model == NULL:
        return 0
    m.model = model

    cdef Tagger *tagger = model.createTagger()
    if tagger == NULL:
        Mecab_clear(m)
        return 0
    m.tagger = tagger

    cdef Lattice *lattice = model.createLattice()
    if lattice == NULL:
        Mecab_clear(m)
        return 0
    m.lattice = lattice
    return 1

cdef njd_node_get_string(_njd.NJDNode* node):
    return (<bytes>(_njd.NJDNode_get_string(node))).decode("utf-8")

cdef njd_node_get_pos(_njd.NJDNode* node):
    return (<bytes>(_njd.NJDNode_get_pos(node))).decode("utf-8")

cdef njd_node_get_pos_group1(_njd.NJDNode* node):
    return (<bytes>(_njd.NJDNode_get_pos_group1(node))).decode("utf-8")

cdef njd_node_get_pos_group2(_njd.NJDNode* node):
    return (<bytes>(_njd.NJDNode_get_pos_group2(node))).decode("utf-8")

cdef njd_node_get_pos_group3(_njd.NJDNode* node):
    return (<bytes>(_njd.NJDNode_get_pos_group3(node))).decode("utf-8")

cdef njd_node_get_ctype(_njd.NJDNode* node):
    return (<bytes>(_njd.NJDNode_get_ctype(node))).decode("utf-8")

cdef njd_node_get_cform(_njd.NJDNode* node):
    return (<bytes>(_njd.NJDNode_get_cform(node))).decode("utf-8")

cdef njd_node_get_orig(_njd.NJDNode* node):
    return (<bytes>(_njd.NJDNode_get_orig(node))).decode("utf-8")

cdef njd_node_get_read(_njd.NJDNode* node):
    return (<bytes>(_njd.NJDNode_get_read(node))).decode("utf-8")

cdef njd_node_get_pron(_njd.NJDNode* node):
    return (<bytes>(_njd.NJDNode_get_pron(node))).decode("utf-8")

cdef njd_node_get_acc(_njd.NJDNode* node):
    return _njd.NJDNode_get_acc(node)

cdef njd_node_get_mora_size(_njd.NJDNode* node):
    return _njd.NJDNode_get_mora_size(node)

cdef njd_node_get_chain_rule(_njd.NJDNode* node):
    return (<bytes>(_njd.NJDNode_get_chain_rule(node))).decode("utf-8")

cdef njd_node_get_chain_flag(_njd.NJDNode* node):
      return _njd.NJDNode_get_chain_flag(node)


cdef njd_node_print(_njd.NJDNode* node):
  return "{},{},{},{},{},{},{},{},{},{},{}/{},{},{}".format(
    njd_node_get_string(node),
    njd_node_get_pos(node),
    njd_node_get_pos_group1(node),
    njd_node_get_pos_group2(node),
    njd_node_get_pos_group3(node),
    njd_node_get_ctype(node),
    njd_node_get_cform(node),
    njd_node_get_orig(node),
    njd_node_get_read(node),
    njd_node_get_pron(node),
    njd_node_get_acc(node),
    njd_node_get_mora_size(node),
    njd_node_get_chain_rule(node),
    njd_node_get_chain_flag(node)
    )


cdef njd_print(_njd.NJD* njd):
    cdef _njd.NJDNode* node = njd.head
    njd_results = []
    while node is not NULL:
      njd_results.append(njd_node_print(node))
      node = node.next
    return njd_results

cdef class OpenJTalk(object):
    """OpenJTalk

    Args:
        dn_mecab (bytes): Dictionaly path for MeCab.
        user_mecab (bytes): Dictionary path for MeCab userdic.
            This option is ignored when empty bytestring is given.
            Default is empty.
    """
    cdef Mecab* mecab
    cdef NJD* njd
    cdef JPCommon* jpcommon

    def __cinit__(self, bytes dn_mecab=b"/usr/local/dic", bytes user_mecab=b""):
        self.mecab = new Mecab()
        self.njd = new NJD()
        self.jpcommon = new JPCommon()

        Mecab_initialize(self.mecab)
        NJD_initialize(self.njd)
        JPCommon_initialize(self.jpcommon)

        r = self._load(dn_mecab, user_mecab)
        if r != 1:
          self._clear()
          raise RuntimeError("Failed to initalize Mecab")


    def _clear(self):
      Mecab_clear(self.mecab)
      NJD_clear(self.njd)
      JPCommon_clear(self.jpcommon)

    def _load(self, bytes dn_mecab, bytes user_mecab):
        return Mecab_load_ex(self.mecab, dn_mecab, user_mecab)


    def run_frontend(self, text, verbose=0):
        """Run OpenJTalk's text processing frontend
        """
        if isinstance(text, str):
          text = text.encode("utf-8")
        cdef char buff[8192]
        text2mecab(buff, text)
        Mecab_analysis(self.mecab, buff)
        mecab2njd(self.njd, Mecab_get_feature(self.mecab), Mecab_get_size(self.mecab))
        _njd.njd_set_pronunciation(self.njd)
        _njd.njd_set_digit(self.njd)
        _njd.njd_set_accent_phrase(self.njd)
        _njd.njd_set_accent_type(self.njd)
        _njd.njd_set_unvoiced_vowel(self.njd)
        _njd.njd_set_long_vowel(self.njd)
        njd2jpcommon(self.jpcommon, self.njd)
        JPCommon_make_label(self.jpcommon)

        cdef int label_size = JPCommon_get_label_size(self.jpcommon)
        cdef char** label_feature
        label_feature = JPCommon_get_label_feature(self.jpcommon)

        labels = []
        for i in range(label_size):
          # This will create a copy of c string
          # http://cython.readthedocs.io/en/latest/src/tutorial/strings.html
          labels.append(<unicode>label_feature[i])

        njd_results = njd_print(self.njd)

        if verbose > 0:
          NJD_print(self.njd)

        # Note that this will release memory for label feature
        JPCommon_refresh(self.jpcommon)
        NJD_refresh(self.njd)
        Mecab_refresh(self.mecab)

        return njd_results, labels

    def mecab_parse(self, text):
        if isinstance(text, str):
            text = text.encode("utf-8")
        cdef char buff[8192]
        text2mecab(buff, text)
        Mecab_analysis(self.mecab, buff)
        cdef char** mecab_feature = Mecab_get_feature(self.mecab)
        cdef int mecab_size = Mecab_get_size(self.mecab)
        features = []
        for i in range(mecab_size):
            features.append((<bytes>mecab_feature[i]).decode("utf-8"))
        Mecab_refresh(self.mecab)
        return features

    def g2p(self, text, kana=False, join=True):
        """Grapheme-to-phoeneme (G2P) conversion
        """
        njd_results, labels = self.run_frontend(text)
        if not kana:
            prons = list(map(lambda s: s.split("-")[1].split("+")[0], labels[1:-1]))
            if join:
                prons = " ".join(prons)
            return prons

        # kana
        prons = []
        for n in njd_results:
            row = n.split(",")
            if row[1] == "記号":
                p = row[0]
            else:
                p = row[9]
            # remove special chars
            for c in "’":
                p = p.replace(c,"")
            prons.append(p)
        if join:
            prons = "".join(prons)
        return prons

    def __dealloc__(self):
        self._clear()
        del self.mecab
        del self.njd
        del self.jpcommon

def CreateUserDict(bytes dn_mecab, bytes path, bytes out_path):
    cdef (char*)[10] argv = [
        "mecab-dict-index",
        "-d",
        dn_mecab,
        "-u",
        out_path,
        "-f",
        "utf-8",
        "-t",
        "utf-8",
        path
    ]
    mecab_dict_index(10, argv)