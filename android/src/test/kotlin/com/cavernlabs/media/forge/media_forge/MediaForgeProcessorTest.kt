package com.cavernlabs.media.forge.media_forge

import android.content.Context
import kotlinx.coroutines.runBlocking
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.fail

class MediaForgeProcessorTest {

    @Test
    fun inspectVideo_throwsWhenFileDoesNotExist() = runBlocking {
        val testContext = FakeContext()
        val processor = MediaForgeProcessor(testContext)

        try {
            processor.inspectVideo("/non/existent/clip.mp4")
            fail("Expected FlutterError for missing file")
        } catch (e: FlutterError) {
            assertEquals("file_not_found", e.code)
        }
    }

    @Test
    fun createVideoThumbnail_throwsWhenFileDoesNotExist() = runBlocking {
        val testContext = FakeContext()
        val processor = MediaForgeProcessor(testContext)

        try {
            processor.createVideoThumbnail("/non/existent/clip.mp4", 0, null, null)
            fail("Expected FlutterError for missing file")
        } catch (e: FlutterError) {
            assertEquals("file_not_found", e.code)
        }
    }
}

private class FakeContext : android.content.ContextWrapper(null)

