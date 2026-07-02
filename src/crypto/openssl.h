#ifdef USE_BORINGSSL
  #define _Pragma(x)
#endif

#include <openssl/ssl.h>
#include <openssl/bio.h>
#include <openssl/err.h>
#include <openssl/dh.h>