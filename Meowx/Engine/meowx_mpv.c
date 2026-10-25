#include "meowx_mpv.h"

#define GL_DO_NOT_WARN_IF_MULTI_GL_VERSION_HEADERS_INCLUDED
#include <OpenGL/gl3.h>
#include <OpenGL/OpenGL.h>
#include <CoreFoundation/CoreFoundation.h>

#include <stdlib.h>
#include <string.h>
#include <pthread.h>

static pthread_mutex_t meowx_gl_mutex = PTHREAD_MUTEX_INITIALIZER;

void meowx_gl_lock(void) {
    pthread_mutex_lock(&meowx_gl_mutex);
}

void meowx_gl_unlock(void) {
    pthread_mutex_unlock(&meowx_gl_mutex);
}

int meowx_command_sep(mpv_handle *ctx, const char *joined) {
    if (!ctx || !joined || !joined[0]) return MPV_ERROR_INVALID_PARAMETER;
    char *copy = strdup(joined);
    if (!copy) return MPV_ERROR_NOMEM;
    const char *args[64];
    int count = 0;
    char *save = NULL;
    for (char *token = strtok_r(copy, "\x1f", &save); token && count < 63; token = strtok_r(NULL, "\x1f", &save)) {
        args[count++] = token;
    }
    args[count] = NULL;
    int result = count > 0 ? mpv_command(ctx, args) : MPV_ERROR_INVALID_PARAMETER;
    free(copy);
    return result;
}

static void *meowx_get_proc(void *ctx, const char *name) {
    (void)ctx;
    if (!name) return NULL;
    CFStringRef symbol = CFStringCreateWithCString(NULL, name, kCFStringEncodingASCII);
    if (!symbol) return NULL;
    CFBundleRef bundle = CFBundleGetBundleWithIdentifier(CFSTR("com.apple.opengl"));
    void *address = bundle ? CFBundleGetFunctionPointerForName(bundle, symbol) : NULL;
    CFRelease(symbol);
    return address;
}

int meowx_gl_create_render(mpv_render_context **out_ctx, mpv_handle *mpv) {
    if (!out_ctx || !mpv) return MPV_ERROR_INVALID_PARAMETER;
    mpv_opengl_init_params gl_init;
    memset(&gl_init, 0, sizeof(gl_init));
    gl_init.get_proc_address = meowx_get_proc;
    gl_init.get_proc_address_ctx = NULL;
    int advanced = 1;
    mpv_render_param params[] = {
        {MPV_RENDER_PARAM_API_TYPE, (void *)MPV_RENDER_API_TYPE_OPENGL},
        {MPV_RENDER_PARAM_OPENGL_INIT_PARAMS, &gl_init},
        {MPV_RENDER_PARAM_ADVANCED_CONTROL, &advanced},
        {0}
    };
    return mpv_render_context_create(out_ctx, mpv, params);
}

static int render_to(mpv_render_context *ctx, int fbo, int width, int height, int flip_y, int block_for_target) {
    if (!ctx || width < 1 || height < 1) return MPV_ERROR_INVALID_PARAMETER;
    mpv_opengl_fbo mpv_fbo = {.fbo = fbo, .w = width, .h = height, .internal_format = 0};
    int flip = flip_y ? 1 : 0;
    int block = block_for_target ? 1 : 0;
    mpv_render_param params[] = {
        {MPV_RENDER_PARAM_OPENGL_FBO, &mpv_fbo},
        {MPV_RENDER_PARAM_FLIP_Y, &flip},
        {MPV_RENDER_PARAM_BLOCK_FOR_TARGET_TIME, &block},
        {0}
    };
    return mpv_render_context_render(ctx, params);
}

int meowx_gl_render(mpv_render_context *ctx, int width, int height, int flip_y, int block) {
    GLint fbo = 0;
    glGetIntegerv(GL_DRAW_FRAMEBUFFER_BINDING, &fbo);
    return render_to(ctx, (int)fbo, width, height, flip_y, block);
}

int meowx_gl_render_fbo(mpv_render_context *ctx, unsigned int fbo, int width, int height, int flip_y) {
    return render_to(ctx, (int)fbo, width, height, flip_y, 0);
}

int meowx_gl_make_fbo(int width, int height, unsigned int *out_fbo, unsigned int *out_texture) {
    if (!out_fbo || !out_texture || width < 1 || height < 1) return -1;
    GLuint texture = 0;
    GLuint fbo = 0;
    glGenTextures(1, &texture);
    glBindTexture(GL_TEXTURE_2D, texture);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glGenFramebuffers(1, &fbo);
    glBindFramebuffer(GL_FRAMEBUFFER, fbo);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, texture, 0);
    GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glBindTexture(GL_TEXTURE_2D, 0);
    if (status != GL_FRAMEBUFFER_COMPLETE) {
        glDeleteFramebuffers(1, &fbo);
        glDeleteTextures(1, &texture);
        return -1;
    }
    *out_fbo = fbo;
    *out_texture = texture;
    return 0;
}

void meowx_gl_read_rgba_flipped(unsigned int fbo, int width, int height, unsigned char *dst) {
    if (!dst || width < 1 || height < 1) return;
    size_t row = (size_t)width * 4;
    unsigned char *tmp = malloc(row * (size_t)height);
    if (!tmp) return;
    glBindFramebuffer(GL_FRAMEBUFFER, fbo);
    glPixelStorei(GL_PACK_ALIGNMENT, 1);
    glReadPixels(0, 0, width, height, GL_RGBA, GL_UNSIGNED_BYTE, tmp);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    for (int y = 0; y < height; y++) {
        memcpy(dst + (size_t)(height - 1 - y) * row, tmp + (size_t)y * row, row);
    }
    free(tmp);
}

void meowx_gl_delete_fbo(unsigned int fbo, unsigned int texture) {
    GLuint fbo_id = fbo;
    GLuint texture_id = texture;
    if (fbo) glDeleteFramebuffers(1, &fbo_id);
    if (texture) glDeleteTextures(1, &texture_id);
}

static CGLPixelFormatObj choose_pixel_format(int double_buffer, uint32_t mask) {
    CGLPixelFormatAttribute attrs[16];
    int count = 0;
    if (mask != 0) {
        attrs[count++] = kCGLPFADisplayMask;
        attrs[count++] = (CGLPixelFormatAttribute)mask;
    }
    attrs[count++] = kCGLPFAAccelerated;
    if (double_buffer) attrs[count++] = kCGLPFADoubleBuffer;
    else attrs[count++] = kCGLPFAAllowOfflineRenderers;
    attrs[count++] = kCGLPFAOpenGLProfile;
    attrs[count++] = (CGLPixelFormatAttribute)kCGLOGLPVersion_3_2_Core;
    attrs[count++] = kCGLPFAColorSize;
    attrs[count++] = (CGLPixelFormatAttribute)24;
    attrs[count++] = kCGLPFAAlphaSize;
    attrs[count++] = (CGLPixelFormatAttribute)8;
    attrs[count++] = 0;

    CGLPixelFormatObj format = NULL;
    GLint npix = 0;
    if (CGLChoosePixelFormat(attrs, &format, &npix) != kCGLNoError) return NULL;
    return format;
}

void *meowx_gl_pixel_format_for_display(uint32_t mask) {
    CGLPixelFormatObj format = choose_pixel_format(1, mask);
    if (!format && mask != 0) format = choose_pixel_format(1, 0);
    return format;
}

void *meowx_gl_offscreen_context(void) {
    CGLPixelFormatObj format = choose_pixel_format(0, 0);
    if (!format) return NULL;
    CGLContextObj context = NULL;
    CGLError error = CGLCreateContext(format, NULL, &context);
    CGLReleasePixelFormat(format);
    if (error != kCGLNoError) return NULL;
    return context;
}

void *meowx_cgl_get_current(void) {
    return CGLGetCurrentContext();
}

void meowx_cgl_set_current(void *ctx) {
    CGLSetCurrentContext((CGLContextObj)ctx);
}

void meowx_cgl_clear_current(void) {
    CGLSetCurrentContext(NULL);
}

void meowx_cgl_release_pixel_format(void *pixel_format) {
    if (pixel_format) CGLReleasePixelFormat((CGLPixelFormatObj)pixel_format);
}

void meowx_cgl_release_context(void *ctx) {
    if (ctx) CGLReleaseContext((CGLContextObj)ctx);
}
