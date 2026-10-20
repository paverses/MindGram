            // MindGram: round video effects — the live circle, and swipes to switch.
            MindGramRoundVideo.resetCurrent()
            MindGramRoundVideo.setPreviewSink({ [weak self] image in
                guard let self else {
                    return
                }
                let uiImage = image.flatMap { UIImage(cgImage: $0) }
                self.mindGramEffectView.image = uiImage
                self.mindGramEffectView.isHidden = uiImage == nil || self.previewState != nil
            })
